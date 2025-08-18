import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Shared metadata extraction logic
async function extractMetadata(url: string) {
  console.log(`🔍 Extracting metadata for: ${url}`);
  
  try {
    // Validate URL
    const urlObj = new URL(url);
    const domain = urlObj.hostname;
    
    // Special handling for YouTube
    if (domain.includes('youtube.com') || domain.includes('youtu.be')) {
      return await extractYouTubeMetadata(url, domain);
    }
    
    // Fetch HTML content
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
      }
    });
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const html = await response.text();
    
    // Extract metadata using regex patterns
    const title = extractTitle(html);
    const description = extractDescription(html);
    const imageUrl = extractImageUrl(html, url);
    const canonicalUrl = extractCanonicalUrl(html, url);
    
    return {
      title,
      description,
      imageUrl,
      canonicalUrl,
      domain,
      contentType: 'article'
    };
    
  } catch (error) {
    console.error(`❌ Error extracting metadata: ${error.message}`);
    
    // Fallback: return basic info from URL
    const urlObj = new URL(url);
    return {
      title: urlObj.hostname,
      description: null,
      imageUrl: null,
      canonicalUrl: url,
      domain: urlObj.hostname,
      contentType: 'article'
    };
  }
}

async function extractYouTubeMetadata(url: string, domain: string) {
  console.log(`🎥 Extracting YouTube metadata for: ${url}`);
  
  // Extract video ID
  const videoId = extractYouTubeVideoId(url);
  if (!videoId) {
    throw new Error('Could not extract YouTube video ID');
  }
  
  // Try oEmbed API first
  try {
    const oEmbedUrl = `https://www.youtube.com/oembed?url=${encodeURIComponent(url)}&format=json`;
    const response = await fetch(oEmbedUrl);
    
    if (response.ok) {
      const data = await response.json();
      return {
        title: data.title || 'YouTube Video',
        description: null,
        imageUrl: `https://img.youtube.com/vi/${videoId}/hqdefault.jpg`,
        canonicalUrl: `https://www.youtube.com/watch?v=${videoId}`,
        domain,
        contentType: 'video'
      };
    }
  } catch (error) {
    console.warn(`⚠️ oEmbed failed, falling back to HTML parsing: ${error.message}`);
  }
  
  // Fallback: parse HTML
  try {
    const response = await fetch(url);
    const html = await response.text();
    const title = extractTitle(html) || 'YouTube Video';
    
    return {
      title,
      description: null,
      imageUrl: `https://img.youtube.com/vi/${videoId}/hqdefault.jpg`,
      canonicalUrl: `https://www.youtube.com/watch?v=${videoId}`,
      domain,
      contentType: 'video'
    };
  } catch (error) {
    console.error(`❌ YouTube HTML parsing failed: ${error.message}`);
    
    return {
      title: 'YouTube Video',
      description: null,
      imageUrl: `https://img.youtube.com/vi/${videoId}/hqdefault.jpg`,
      canonicalUrl: `https://www.youtube.com/watch?v=${videoId}`,
      domain,
      contentType: 'video'
    };
  }
}

function extractYouTubeVideoId(url: string): string | null {
  const patterns = [
    /(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([^&\n?#]+)/,
    /youtube\.com\/watch\?.*v=([^&\n?#]+)/
  ];
  
  for (const pattern of patterns) {
    const match = url.match(pattern);
    if (match) {
      return match[1];
    }
  }
  
  return null;
}

function extractTitle(html: string): string {
  // Try og:title first
  let match = html.match(/<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']/i);
  if (match) return match[1];
  
  // Try twitter:title
  match = html.match(/<meta[^>]+name=["']twitter:title["'][^>]+content=["']([^"']+)["']/i);
  if (match) return match[1];
  
  // Try regular title tag
  match = html.match(/<title[^>]*>([^<]+)</i);
  if (match) return match[1].trim();
  
  return '';
}

function extractDescription(html: string): string | null {
  // Try meta description
  let match = html.match(/<meta[^>]+name=["']description["'][^>]+content=["']([^"']+)["']/i);
  if (match) return match[1];
  
  // Try og:description
  match = html.match(/<meta[^>]+property=["']og:description["'][^>]+content=["']([^"']+)["']/i);
  if (match) return match[1];
  
  return null;
}

function extractImageUrl(html: string, baseUrl: string): string | null {
  // Try og:image
  let match = html.match(/<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i);
  if (match) return resolveUrl(match[1], baseUrl);
  
  // Try twitter:image
  match = html.match(/<meta[^>]+name=["']twitter:image["'][^>]+content=["']([^"']+)["']/i);
  if (match) return resolveUrl(match[1], baseUrl);
  
  return null;
}

function extractCanonicalUrl(html: string, fallbackUrl: string): string {
  const match = html.match(/<link[^>]+rel=["']canonical["'][^>]+href=["']([^"']+)["']/i);
  const found = match ? match[1] : null;
  return (found && found !== 'undefined') ? found : fallbackUrl;
}

function resolveUrl(url: string, baseUrl: string): string {
  try {
    return new URL(url, baseUrl).href;
  } catch {
    return url;
  }
}

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    // Get the authorization header
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ 
          error: 'Authentication required to save items',
          details: 'Missing Authorization header'
        }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Initialize Supabase client with the user's token for authentication
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      },
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    });

    // Verify user authentication by getting the current user
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    
    if (authError || !user) {
      console.error('❌ Authentication failed:', authError);
      return new Response(
        JSON.stringify({ 
          error: 'Authentication required to save items',
          details: authError?.message || 'Invalid or expired token'
        }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      );
    }

    console.log(`🔐 Authenticated user: ${user.email} (${user.id})`);

    const { url } = await req.json();
    
    if (!url) {
      return new Response(
        JSON.stringify({ error: 'URL is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    console.log(`📝 Manual add request for: ${url}`);

    // Extract metadata
    const metadata = await extractMetadata(url);
    
    // Check for duplicates using canonical URL and user_id
    const canonicalUrl = metadata.canonicalUrl || url;
    const { data: existingItems } = await supabase
      .from('items')
      .select('id, title, status')
      .eq('user_id', user.id)
      .or(`url.eq.${url},canonical_url.eq.${canonicalUrl}`);

    if (existingItems && existingItems.length > 0) {
      const existing = existingItems[0];
      console.log(`♻️ Item already exists for user: ${existing.title}`);
      
      return new Response(
        JSON.stringify({
          id: existing.id,
          message: 'Item already exists',
          existing: true,
          status: existing.status
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Insert new item with user_id
    const itemData = {
      user_id: user.id,
      url,
      canonical_url: metadata.canonicalUrl,
      domain: metadata.domain,
      title: metadata.title,
      description: metadata.description,
      image_url: metadata.imageUrl,
      content_type: metadata.contentType,
      status: 'unread',
      source_client: 'app_manual',
      source_platform: 'flutter_app',
      metadata: {
        extraction_method: 'manual_add',
        canonical: metadata.canonicalUrl,
        image_sources: metadata.imageUrl ? { extracted: metadata.imageUrl } : {},
        title_sources: metadata.title ? { extracted: metadata.title } : {},
        description_sources: metadata.description ? { extracted: metadata.description } : {}
      }
    };

    const { data: newItem, error } = await supabase
      .from('items')
      .insert(itemData)
      .select()
      .single();

    if (error) {
      console.error('❌ Database error:', error);
      throw error;
    }

    console.log(`✅ Item added successfully: ${newItem.title}`);

    return new Response(
      JSON.stringify({
        id: newItem.id,
        status: newItem.status,
        content_type: newItem.content_type,
        title: newItem.title,
        description: newItem.description,
        image_url: newItem.image_url,
        domain: newItem.domain,
        added_at: newItem.added_at
      }),
      { status: 201, headers: { 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('❌ Error in add-item-manual:', error);
    
    return new Response(
      JSON.stringify({ 
        error: error.message || 'Internal server error',
        details: error.toString()
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
