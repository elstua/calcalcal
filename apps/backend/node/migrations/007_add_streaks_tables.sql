-- Streaks feature migration
-- Adds tables for tracking user streaks and streak history

-- User streaks table for current streak tracking
CREATE TABLE IF NOT EXISTS "public"."user_streaks" (
    "user_id" "uuid" NOT NULL,
    "current_streak" integer DEFAULT 0,
    "longest_streak" integer DEFAULT 0,
    "last_entry_date" "date",
    "streak_start_date" "date",
    "total_days_with_entries" integer DEFAULT 0,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "user_streaks_pkey" PRIMARY KEY ("user_id"),
    CONSTRAINT "user_streaks_current_streak_check" CHECK (("current_streak" >= 0)),
    CONSTRAINT "user_streaks_longest_streak_check" CHECK (("longest_streak" >= 0)),
    CONSTRAINT "user_streaks_total_days_check" CHECK (("total_days_with_entries" >= 0))
);

-- Streak history table for completed streaks
CREATE TABLE IF NOT EXISTS "public"."streak_history" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "streak_length" integer NOT NULL,
    "start_date" "date" NOT NULL,
    "end_date" "date" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "streak_history_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "streak_history_streak_length_check" CHECK (("streak_length" > 0)),
    CONSTRAINT "streak_history_date_order_check" CHECK (("end_date" >= "start_date"))
);

-- Function to check if a diary entry has meaningful content
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
    
    return block_count > 0::bool;
end;
$$;

-- Function to update user streaks when diary entries change
CREATE OR REPLACE FUNCTION "public"."update_user_streak"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
    user_timezone_offset integer := 0;
    yesterday_date date;
    today_date date;
    has_content boolean;
    current_streak_val integer;
begin
    -- Get user's timezone offset for accurate date calculation
    select coalesce(timezone_offset, 0) into user_timezone_offset
    from "public"."user_profiles"
    where id = new.user_id;
    
    -- Calculate dates considering timezone
    today_date := (new.created_at at time zone (user_timezone_offset || ' minutes'))::date;
    yesterday_date := today_date - interval '1 day';
    
    -- Check if entry has meaningful content
    has_content := public.has_meaningful_content(new.content, new.blocks);
    
    -- Get current streak
    select coalesce(current_streak, 0) into current_streak_val
    from "public"."user_streaks"
    where user_id = new.user_id;
    
    if has_content then
        -- User has meaningful content - update streak
        insert into "public"."user_streaks" (
            user_id, 
            current_streak, 
            longest_streak, 
            last_entry_date, 
            streak_start_date,
            total_days_with_entries,
            updated_at
        ) values (
            new.user_id,
            case 
                when last_entry_date = yesterday_date then current_streak_val + 1
                when last_entry_date = today_date then current_streak_val -- same day update
                else 1 -- new streak
            end,
            greatest(
                coalesce(longest_streak, 0),
                case 
                    when last_entry_date = yesterday_date then current_streak_val + 1
                    when last_entry_date = today_date then current_streak_val
                    else 1
                end
            ),
            today_date,
            case 
                when last_entry_date = yesterday_date then streak_start_date
                when last_entry_date = today_date then streak_start_date
                else today_date
            end,
            coalesce(total_days_with_entries, 0) + 1,
            now()
        )
        on conflict (user_id) do update set
            current_streak = excluded.current_streak,
            longest_streak = excluded.longest_streak,
            last_entry_date = excluded.last_entry_date,
            streak_start_date = excluded.streak_start_date,
            total_days_with_entries = excluded.total_days_with_entries,
            updated_at = now();
            
    else
        -- Entry has no meaningful content - check if this breaks the streak
        if last_entry_date = yesterday_date then
            -- User had a streak yesterday but no content today - move to history
            insert into "public"."streak_history" (
                user_id, 
                streak_length, 
                start_date, 
                end_date
            ) values (
                new.user_id,
                current_streak_val,
                streak_start_date,
                yesterday_date
            );
            
            -- Reset current streak
            insert into "public"."user_streaks" (
                user_id, 
                current_streak, 
                longest_streak, 
                last_entry_date, 
                streak_start_date,
                total_days_with_entries,
                updated_at
            ) values (
                new.user_id,
                0,
                longest_streak,
                null,
                null,
                total_days_with_entries,
                now()
            )
            on conflict (user_id) do update set
                current_streak = 0,
                last_entry_date = null,
                streak_start_date = null,
                updated_at = now();
        end if;
    end if;
    
    return new;
end;
$$;

-- Indexes for performance
CREATE INDEX IF NOT EXISTS "idx_user_streaks_user_id" ON "public"."user_streaks" USING "btree" ("user_id");
CREATE INDEX IF NOT EXISTS "idx_streak_history_user_id" ON "public"."streak_history" USING "btree" ("user_id");
CREATE INDEX IF NOT EXISTS "idx_streak_history_dates" ON "public"."streak_history" USING "btree" ("start_date", "end_date");

-- Triggers for automatic streak updates
DROP TRIGGER IF EXISTS "update_streak_on_diary_change" ON "public"."diary_entries";
CREATE TRIGGER "update_streak_on_diary_change" 
    AFTER INSERT OR UPDATE ON "public"."diary_entries" 
    FOR EACH ROW EXECUTE FUNCTION "public"."update_user_streak"();

-- Initialize streaks for existing users
INSERT INTO "public"."user_streaks" (user_id, current_streak, longest_streak, total_days_with_entries)
SELECT 
    id as user_id,
    0 as current_streak,
    0 as longest_streak,
    0 as total_days_with_entries
FROM "public"."user_profiles"
WHERE id NOT IN (SELECT user_id FROM "public"."user_streaks");