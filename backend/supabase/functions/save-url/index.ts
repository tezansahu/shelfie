import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

interface SaveUrlRequest {
  url: string;
  source_client?: string;
  source_platform?: string;
}

interface MetaData {
  title?: string;
  description?: string;
  image_url?: string;
  canonical_url?: string;
  raw: Record<string, any>;
}

// Extract YouTube video ID from various URL formats
function extractYouTubeId(url: URL): string | null {
  const hostname = url.hostname;
  
  if (hostname.includes('youtube.com')) {
    const searchParams = url.searchParams;
    return searchParams.get('v');
  }
  
  if (hostname.includes('youtu.be')) {
    return url.pathname.slice(1); // Remove leading slash
  }
  
  return null;
}

// Fetch YouTube video title via oEmbed API
async function fetchYouTubeOEmbed(videoUrl: string): Promise<string | null> {
  try {
    const oembedUrl = `https://www.youtube.com/oembed?url=${encodeURIComponent(videoUrl)}&format=json`;
    const response = await fetch(oembedUrl);
    
    if (response.ok) {
      const data = await response.json();
      return data.title || null;
    }
  } catch (error) {
    console.error('Failed to fetch YouTube oEmbed:', error);
  }
  
  return null;
}

// Parse HTML meta tags
function parseMeta(html: string): MetaData {
  const meta: MetaData = { raw: {} };
  
  // Extract title
  const titleMatch = html.match(/<title[^>]*>([^<]+)<\/title>/i);
  const ogTitleMatch = html.match(/<meta[^>]*property="og:title"[^>]*content="([^"]+)"/i);
  const twitterTitleMatch = html.match(/<meta[^>]*name="twitter:title"[^>]*content="([^"]+)"/i);
  
  meta.title = ogTitleMatch?.[1] || twitterTitleMatch?.[1] || titleMatch?.[1] || undefined;
  
  // Extract description
  const descMatch = html.match(/<meta[^>]*name="description"[^>]*content="([^"]+)"/i);
  const ogDescMatch = html.match(/<meta[^>]*property="og:description"[^>]*content="([^"]+)"/i);
  
  meta.description = descMatch?.[1] || ogDescMatch?.[1] || undefined;
  
  // Extract image
  const ogImageMatch = html.match(/<meta[^>]*property="og:image"[^>]*content="([^"]+)"/i);
  const twitterImageMatch = html.match(/<meta[^>]*name="twitter:image"[^>]*content="([^"]+)"/i);
  
  meta.image_url = ogImageMatch?.[1] || twitterImageMatch?.[1] || undefined;
  
  // Extract canonical URL (ignore literal 'undefined' which sometimes appears due to bad templates)
  const canonicalMatch = html.match(/<link[^>]*rel="canonical"[^>]*href="([^"]+)"/i);
  const canonicalFound = canonicalMatch?.[1];
  meta.canonical_url = (canonicalFound && canonicalFound !== 'undefined') ? canonicalFound : undefined;
  
  // Store raw data for debugging
  meta.raw = {
    title_sources: {
      title_tag: titleMatch?.[1],
      og_title: ogTitleMatch?.[1],
      twitter_title: twitterTitleMatch?.[1]
    },
    description_sources: {
      meta_description: descMatch?.[1],
      og_description: ogDescMatch?.[1]
    },
    image_sources: {
      og_image: ogImageMatch?.[1],
      twitter_image: twitterImageMatch?.[1]
    },
    canonical: canonicalMatch?.[1]
  };
  
  return meta;
}

// Strip common tracking parameters
function stripTrackingParams(url: URL): URL {
  const trackingParams = [
    'utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term',
    'fbclid', 'gclid', 'ref', 'source'
  ];
  
  trackingParams.forEach(param => {
    url.searchParams.delete(param);
  });
  
  return url;
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // Get the authorization header (Supabase JWT from the extension)
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Authentication required to save items', details: 'Missing Authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Initialize Supabase client with service role key but forward user's token for RLS/auth.uid()
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
      global: { headers: { Authorization: authHeader } }
    });

    // Verify user authentication
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      console.error('Authentication failed:', authError);
      return new Response(
        JSON.stringify({ error: 'Authentication required to save items', details: authError?.message || 'Invalid or expired token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`Authenticated user: ${user.email} (${user.id})`);

    const requestBody: SaveUrlRequest = await req.json();
    const { 
      url, 
      source_client = 'browser_extension', 
      source_platform = 'chrome' 
    } = requestBody;

    if (!url) {
      throw new Error('URL is required');
    }

    // Parse and validate URL
    const parsedUrl = new URL(url);
    const cleanUrl = stripTrackingParams(new URL(url));
    const domain = parsedUrl.hostname;

  console.log(`Processing URL: ${url} (domain: ${domain}) for user: ${user.id}`);

    // Check for existing item to prevent duplicates (for this user)
    const { data: existingItem } = await supabase
      .from('items')
      .select('id, url, canonical_url')
      .eq('user_id', user.id)
      .or(`url.eq.${url},canonical_url.eq.${url},url.eq.${cleanUrl.toString()},canonical_url.eq.${cleanUrl.toString()}`)
      .maybeSingle();

    if (existingItem) {
      console.log('Item already exists:', existingItem.id);
      return new Response(
        JSON.stringify({ 
          message: 'Item already exists', 
          id: existingItem.id,
          existing: true 
        }), 
        { 
          status: 200, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      );
    }

    // Fetch HTML content
    console.log('Fetching HTML content...');
    const fetchResponse = await fetch(url, {
      headers: {
        'User-Agent': 'ReadLaterBot/1.0 (Shelfie Save Service)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
      }
    });

    if (!fetchResponse.ok) {
      throw new Error(`Failed to fetch content: ${fetchResponse.status} ${fetchResponse.statusText}`);
    }

    const html = await fetchResponse.text();
    console.log('HTML fetched, parsing metadata...');

    // Parse basic metadata
    const meta = parseMeta(html);
    
  // Initialize content variables
  let content_type = 'article';
  let image_url: string | null = meta.image_url ?? null;
  let title = meta.title;
  let description: string | null = meta.description ?? null;

    // Special handling for YouTube
    const youtubeId = extractYouTubeId(parsedUrl);
    if (youtubeId) {
      console.log(`Detected YouTube video: ${youtubeId}`);
      content_type = 'video';
      
      // Try to get better title from oEmbed
      const oembedTitle = await fetchYouTubeOEmbed(url);
      title = oembedTitle || title || `YouTube Video (${youtubeId})`;
      
      // Use high-quality thumbnail
      image_url = `https://img.youtube.com/vi/${youtubeId}/hqdefault.jpg`;
      
      // Videos don't need description
      description = null;
    }

    // Resolve relative image URLs to absolute
    if (image_url) {
      try {
        image_url = new URL(image_url, url).toString();
      } catch (error) {
        console.error('Failed to resolve image URL:', error);
        image_url = null;
      }
    }

  // Resolve canonical URL
  let canonical_url: string | null = null;
    // If this is a YouTube video, build a stable canonical using the video id.
    // This avoids cases where pages or parsers accidentally yield the string "undefined"
    // which would resolve to e.g. https://www.youtube.com/undefined.
    if (youtubeId) {
      canonical_url = `https://www.youtube.com/watch?v=${youtubeId}`;
    } else if (meta.canonical_url && meta.canonical_url !== 'undefined') {
      try {
        canonical_url = new URL(meta.canonical_url, url).toString();
      } catch (error) {
        console.error('Failed to resolve canonical URL:', error);
      }
    }

    // Fallback title if none found
    if (!title) {
      title = domain || 'Untitled';
    }

    console.log('Inserting item into database...');

    // Insert into database
  const { data, error } = await supabase
      .from('items')
      .insert({
    user_id: user.id,  // Associate with authenticated user
        url: cleanUrl.toString(),
        canonical_url,
        domain,
        title: title.substring(0, 500), // Limit title length
        description: description?.substring(0, 1000) || null, // Limit description length
        image_url,
        content_type,
        status: 'unread',
        source_client,
        source_platform,
        metadata: meta.raw
      })
      .select()
      .single();

    if (error) {
      console.error('Database error:', error);
      throw error;
    }

    console.log('Item saved successfully:', data.id);

    return new Response(
      JSON.stringify(data), 
      { 
        status: 201, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );

  } catch (error) {
    console.error('Error in save-url function:', error);
    
    return new Response(
      JSON.stringify({ 
        error: error.message,
        details: error.stack 
      }), 
      { 
        status: 400, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );
  }
});
