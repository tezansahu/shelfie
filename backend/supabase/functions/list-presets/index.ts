import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  if (req.method !== 'GET') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    console.log('📋 Fetching preset tags');

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Get all preset tags with usage counts
    const { data: tags, error } = await supabase
      .rpc('get_all_tags', { user_id_param: null });

    if (error) {
      console.error('❌ Database error:', error);
      throw error;
    }

    console.log(`✅ Retrieved ${tags?.length || 0} tags`);

    // Group by type
    const presets = tags?.filter(tag => tag.type === 'preset') || [];
    const customs = tags?.filter(tag => tag.type === 'custom') || [];

    return new Response(
      JSON.stringify({
        presets: presets.map(tag => ({
          id: tag.id,
          name: tag.name,
          usage_count: parseInt(tag.usage_count || '0')
        })),
        custom: customs.map(tag => ({
          id: tag.id,
          name: tag.name,
          usage_count: parseInt(tag.usage_count || '0')
        })),
        total_count: tags?.length || 0
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('❌ Error in list-presets:', error);
    
    return new Response(
      JSON.stringify({ 
        error: error.message || 'Internal server error',
        details: error.toString()
      }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
