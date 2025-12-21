CREATE OR REPLACE FUNCTION "public"."update_user_streak"() RETURNS "trigger"
    LANGUAGE "plpgsql"
AS $$
declare
    user_timezone_offset integer := 0;
    yesterday_date date;
    today_date date;
    has_content boolean;
    current_streak_val integer;
    current_longest_streak_val integer;
    current_total_days_val integer;
    current_streak_start_val date;
    existing_streaks record;
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
    
    -- Get current streaks data if exists
    select * into existing_streaks
    from "public"."user_streaks"
    where user_id = new.user_id;
    
    -- Set current values or defaults
    current_streak_val := coalesce(existing_streaks.current_streak, 0);
    current_longest_streak_val := coalesce(existing_streaks.longest_streak, 0);
    current_total_days_val := coalesce(existing_streaks.total_days_with_entries, 0);
    current_streak_start_val := existing_streaks.streak_start_date;
    
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
                when existing_streaks.last_entry_date = yesterday_date then current_streak_val + 1
                when existing_streaks.last_entry_date = today_date then current_streak_val -- same day update
                else 1 -- new streak
            end,
            greatest(
                current_longest_streak_val,
                case 
                    when existing_streaks.last_entry_date = yesterday_date then current_streak_val + 1
                    when existing_streaks.last_entry_date = today_date then current_streak_val
                    else 1
                end
            ),
            today_date,
            case 
                when existing_streaks.last_entry_date = yesterday_date then current_streak_start_val
                when existing_streaks.last_entry_date = today_date then current_streak_start_val
                else today_date
            end,
            current_total_days_val + 1,
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
        if existing_streaks.last_entry_date = yesterday_date then
            -- User had a streak yesterday but no content today - move to history
            insert into "public"."streak_history" (
                user_id, 
                streak_length, 
                start_date, 
                end_date
            ) values (
                new.user_id,
                current_streak_val,
                current_streak_start_val,
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
                current_longest_streak_val,
                null,
                null,
                current_total_days_val,
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