-- Fix has_meaningful_content function to correctly compare integer and boolean
CREATE OR REPLACE FUNCTION "public"."has_meaningful_content"("entry_content" "text", "entry_blocks" "jsonb") RETURNS "bool"
    LANGUAGE "plpgsql"
    AS $$
declare
    content_trimmed text;
    block_count integer;
begin
    -- Check if content has meaningful text beyond placeholders
    content_trimmed := trim(coalesce(entry_content, ''));
    
    -- Define placeholder prompts that indicate empty/placeholder content
    if content_trimmed ilike '%what did you eat today%' or
       content_trimmed ilike '%describe your meals%' or
       content_trimmed ilike '%breakfast:%' and length(content_trimmed) < 50 or
       content_trimmed ilike '%lunch:%' and length(content_trimmed) < 50 or
       content_trimmed ilike '%dinner:%' and length(content_trimmed) < 50 or
       content_trimmed = '' then
        return false;
    end if;
    
    -- Check if there are any blocks with meaningful content
    block_count := (
        select count(*)
        from jsonb_array_elements(coalesce(entry_blocks, '[]'::jsonb)) as block
        where trim(coalesce(block->>'content', '')) <> ''
           and length(coalesce(block->>'content', '')) > 3
    );
    
    -- FIX: Removed ::bool cast which caused "operator does not exist: integer > boolean" error
    return block_count > 0;
end;
$$;
