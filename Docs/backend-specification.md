# Calcalcal Backend Specification (Supabase Implementation)
## Project Overview

### What is Calcalcal?
Calcalcal is an iOS calorie tracking app that allows users to log food in natural language and automatically calculates nutritional information using AI. The app provides a simple, intuitive interface for users to track their daily calorie intake and nutritional goals.

### Core Features
- **Natural Language Food Logging**: Users can describe their meals in plain English (e.g., "I had a chicken sandwich with fries for lunch")
- **AI-Powered Analysis**: OpenAI integration automatically extracts nutritional data from text descriptions
- **Image Recognition**: Users can upload food photos for automatic calorie analysis
- **Daily Tracking**: Comprehensive diary entries with detailed nutritional breakdowns
- **Goal Setting**: Personalized daily calorie and macro goals
- **Apple Sign-In**: Seamless authentication using Apple's identity system

### App Architecture
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   iOS App       │    │   Supabase      │    │   OpenAI API    │
│   (SwiftUI)     │◄──►│   Backend       │◄──►│   (AI Analysis) │
│                 │    │                 │    │                 │
│ • User Interface│    │ • PostgreSQL DB │    │ • GPT-4         │
│ • Local Storage │    │ • Auth System   │    │ • Image Analysis│
│ • Offline Sync  │    │ • File Storage  │    │ • Nutrition DB  │
│ • Real-time UI  │    │ • Edge Functions│    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### User Flow
1. **Authentication**: User signs in with Apple ID
2. **Food Logging**: User types natural language description or uploads photo
3. **AI Analysis**: Backend processes text/image through OpenAI
4. **Nutrition Calculation**: AI returns detailed nutritional breakdown
5. **Data Storage**: Results stored in PostgreSQL with real-time sync
6. **Goal Tracking**: App compares daily intake against user goals

### Technical Stack
- **Frontend**: iOS app built with SwiftUI and UIKit
- **Backend**: Supabase (PostgreSQL + Auth + Storage + Edge Functions)
- **AI**: OpenAI GPT-4 for natural language processing
- **Real-time**: Supabase subscriptions for live updates
- **Storage**: Supabase Storage for image uploads
- **Authentication**: Apple Sign-In with custom JWT handling

## Backend Overview
This document outlines the backend specification for the Calcalcal iOS calorie tracking app using Supabase as the backend-as-a-service platform. This approach provides rapid development for MVP while maintaining scalability and type safety.

## Technology Stack

### Core Platform
- **Backend**: Supabase (PostgreSQL + Auth + Storage + Edge Functions)
- **Database**: PostgreSQL with Row Level Security (RLS)
- **Authentication**: Supabase Auth + Custom Apple Sign-In integration
- **Storage**: Supabase Storage for images
- **AI Processing**: Supabase Edge Functions for OpenAI integration
- **Real-time**: Supabase Realtime subscriptions
- **Type Safety**: Auto-generated TypeScript types

### Development Tools
- **CLI**: Supabase CLI for local development
- **Type Generation**: `supabase gen types typescript`
- **Local Development**: `supabase start` for local stack

## Database Schema

### Users Table (Extended from Supabase Auth)
```sql
-- Extend auth.users with custom fields
CREATE TABLE public.user_profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  email TEXT,
  name TEXT,
  apple_id TEXT UNIQUE,
  daily_calorie_goal INTEGER DEFAULT 2000,
  daily_protein_goal DECIMAL DEFAULT 50.0, -- grams
  daily_fat_goal DECIMAL DEFAULT 65.0, -- grams
  daily_carb_goal DECIMAL DEFAULT 250.0, -- grams
  units TEXT DEFAULT 'kcal' CHECK (units IN ('kcal', 'kJ')),
  timezone_offset INTEGER DEFAULT 0, -- minutes from UTC
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own profile" ON public.user_profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.user_profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.user_profiles
  FOR INSERT WITH CHECK (auth.uid() = id);
```

### Diary Entries Table (Unified Design)
```sql
CREATE TABLE public.diary_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  date DATE NOT NULL,
  
  -- Content: The actual text content of the diary entry
  content TEXT DEFAULT '',
  
  -- Parsed blocks: JSON array of analyzed blocks
  blocks JSONB DEFAULT '[]'::jsonb,
  
  -- Daily totals (calculated from blocks)
  total_calories INTEGER DEFAULT 0,
  total_protein DECIMAL DEFAULT 0.0,
  total_fat DECIMAL DEFAULT 0.0,
  total_carbs DECIMAL DEFAULT 0.0,
  total_fiber DECIMAL DEFAULT 0.0,
  total_sugar DECIMAL DEFAULT 0.0,
  total_sodium DECIMAL DEFAULT 0.0,
  
  -- AI analysis status
  ai_analysis_status TEXT DEFAULT 'pending' CHECK (ai_analysis_status IN ('pending', 'processing', 'completed', 'failed')),
  ai_analysis_error TEXT,
  
  -- Images: Array of image URLs for this entry
  images TEXT[] DEFAULT '{}',
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- One entry per user per day
  UNIQUE(user_id, date)
);

-- Indexes for performance
CREATE INDEX idx_diary_entries_user_date ON public.diary_entries(user_id, date);
CREATE INDEX idx_diary_entries_date ON public.diary_entries(date);
CREATE INDEX idx_diary_entries_ai_status ON public.diary_entries(ai_analysis_status);

-- Enable RLS
ALTER TABLE public.diary_entries ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own entries" ON public.diary_entries
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own entries" ON public.diary_entries
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own entries" ON public.diary_entries
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own entries" ON public.diary_entries
  FOR DELETE USING (auth.uid() = user_id);
```

### Popular Food Items Table
```sql
CREATE TABLE public.popular_food_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  name TEXT NOT NULL,
  calories INTEGER NOT NULL,
  protein DECIMAL DEFAULT 0.0,
  fat DECIMAL DEFAULT 0.0,
  carbs DECIMAL DEFAULT 0.0,
  fiber DECIMAL DEFAULT 0.0,
  sugar DECIMAL DEFAULT 0.0,
  sodium DECIMAL DEFAULT 0.0,
  usage_count INTEGER DEFAULT 1,
  last_used TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Allow global items (user_id = NULL) and user-specific items
  UNIQUE(user_id, name)
);

-- Indexes
CREATE INDEX idx_popular_food_user ON public.popular_food_items(user_id);
CREATE INDEX idx_popular_food_usage ON public.popular_food_items(usage_count DESC);

-- Enable RLS
ALTER TABLE public.popular_food_items ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view own and global food items" ON public.popular_food_items
  FOR SELECT USING (user_id = auth.uid() OR user_id IS NULL);

CREATE POLICY "Users can insert own food items" ON public.popular_food_items
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own food items" ON public.popular_food_items
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "Users can delete own food items" ON public.popular_food_items
  FOR DELETE USING (user_id = auth.uid());
```

### AI Analysis Cache Table (for performance)
```sql
CREATE TABLE public.ai_analysis_cache (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content_hash TEXT UNIQUE NOT NULL, -- Hash of the analyzed text
  content TEXT NOT NULL,
  analysis_result JSONB NOT NULL,
  confidence DECIMAL DEFAULT 0.0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Index for quick lookups
  UNIQUE(content_hash)
);

CREATE INDEX idx_ai_cache_content_hash ON public.ai_analysis_cache(content_hash);

-- Enable RLS (but allow all authenticated users to read)
ALTER TABLE public.ai_analysis_cache ENABLE ROW LEVEL SECURITY;

CREATE POLICY "All users can read AI cache" ON public.ai_analysis_cache
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "All users can insert AI cache" ON public.ai_analysis_cache
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');
```

### Database Functions and Triggers

#### Content Processing Functions
```sql
-- Function to parse content into blocks
CREATE OR REPLACE FUNCTION public.parse_content_into_blocks(content_text TEXT)
RETURNS JSONB AS $$
DECLARE
  blocks JSONB := '[]'::jsonb;
  paragraphs TEXT[];
  paragraph TEXT;
  block_count INTEGER := 0;
BEGIN
  -- Split content by double newlines (paragraphs)
  paragraphs := string_to_array(content_text, E'\n\n');
  
  -- Create blocks from paragraphs
  FOREACH paragraph IN ARRAY paragraphs
  LOOP
    -- Skip empty paragraphs
    IF trim(paragraph) != '' THEN
      block_count := block_count + 1;
      
      -- Add block to array
      blocks := blocks || jsonb_build_object(
        'id', gen_random_uuid()::text,
        'position', block_count,
        'content', trim(paragraph),
        'type', 'text',
        'calories', 0,
        'protein', 0.0,
        'fat', 0.0,
        'carbs', 0.0,
        'fiber', 0.0,
        'sugar', 0.0,
        'sodium', 0.0,
        'confidence', 0.0,
        'ai_analysis', null,
        'created_at', now()
      );
    END IF;
  END LOOP;
  
  RETURN blocks;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate totals from blocks
CREATE OR REPLACE FUNCTION public.calculate_diary_totals(blocks_json JSONB)
RETURNS JSONB AS $$
DECLARE
  totals JSONB;
BEGIN
  SELECT jsonb_build_object(
    'total_calories', COALESCE(SUM((block->>'calories')::integer), 0),
    'total_protein', COALESCE(SUM((block->>'protein')::decimal), 0.0),
    'total_fat', COALESCE(SUM((block->>'fat')::decimal), 0.0),
    'total_carbs', COALESCE(SUM((block->>'carbs')::decimal), 0.0),
    'total_fiber', COALESCE(SUM((block->>'fiber')::decimal), 0.0),
    'total_sugar', COALESCE(SUM((block->>'sugar')::decimal), 0.0),
    'total_sodium', COALESCE(SUM((block->>'sodium')::decimal), 0.0)
  ) INTO totals
  FROM jsonb_array_elements(blocks_json) AS block;
  
  RETURN totals;
END;
$$ LANGUAGE plpgsql;

-- Function to update diary entry when content changes
CREATE OR REPLACE FUNCTION public.update_diary_entry_content()
RETURNS TRIGGER AS $$
DECLARE
  new_blocks JSONB;
  new_totals JSONB;
BEGIN
  -- Only process if content changed
  IF OLD.content IS DISTINCT FROM NEW.content THEN
    -- Parse content into blocks
    new_blocks := public.parse_content_into_blocks(NEW.content);
    
    -- Update blocks
    NEW.blocks := new_blocks;
    
    -- Calculate totals
    new_totals := public.calculate_diary_totals(new_blocks);
    
    -- Update totals
    NEW.total_calories := (new_totals->>'total_calories')::integer;
    NEW.total_protein := (new_totals->>'total_protein')::decimal;
    NEW.total_fat := (new_totals->>'total_fat')::decimal;
    NEW.total_carbs := (new_totals->>'total_carbs')::decimal;
    NEW.total_fiber := (new_totals->>'total_fiber')::decimal;
    NEW.total_sugar := (new_totals->>'total_sugar')::decimal;
    NEW.total_sodium := (new_totals->>'total_sodium')::decimal;
    
    -- Reset AI analysis status
    NEW.ai_analysis_status := 'pending';
    NEW.ai_analysis_error := null;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for content updates
CREATE TRIGGER update_diary_content_trigger
  BEFORE UPDATE ON public.diary_entries
  FOR EACH ROW EXECUTE FUNCTION public.update_diary_entry_content();
```

## API Endpoints (Supabase Client)

### Authentication
```typescript
// Apple Sign-In (Custom Edge Function)
POST /functions/v1/auth/apple-signin
Body: {
  identityToken: string,
  authorizationCode?: string,
  user: {
    id: string,
    email?: string,
    name?: string
  }
}

// Refresh token
POST /functions/v1/auth/refresh
Body: {
  refreshToken: string
}

// Get current user
GET /rest/v1/user_profiles?select=*&id=eq.{user_id}

// Update profile
PATCH /rest/v1/user_profiles?id=eq.{user_id}
Body: {
  name?: string,
  daily_calorie_goal?: number,
  units?: 'kcal' | 'kJ'
}

// Sign out
POST /auth/v1/logout
```

### Diary Entries (Simplified API)
```typescript
// Get entries (paginated)
GET /rest/v1/diary_entries?select=*&user_id=eq.{user_id}&date=gte.{start_date}&date=lte.{end_date}&order=date.desc&limit={limit}&offset={offset}

// Get entry by date
GET /rest/v1/diary_entries?select=*&user_id=eq.{user_id}&date=eq.{date}

// Create entry
POST /rest/v1/diary_entries
Body: {
  date: string, // YYYY-MM-DD
  content?: string, // Initial text content
  images?: string[] // Array of image URLs
}

// Update entry content (triggers automatic block parsing and total calculation)
PATCH /rest/v1/diary_entries?id=eq.{entry_id}
Body: {
  content?: string, // Updated text content
  images?: string[] // Updated image URLs
}

// Update entry with AI analysis results
PATCH /rest/v1/diary_entries?id=eq.{entry_id}
Body: {
  blocks?: JSONB, // Updated blocks with nutrition data
  ai_analysis_status?: 'completed' | 'failed',
  ai_analysis_error?: string
}

// Delete entry
DELETE /rest/v1/diary_entries?id=eq.{entry_id}
```

### AI Analysis
```typescript
// Submit for AI analysis (async)
POST /functions/v1/ai/analyze
Body: {
  entryId: string,
  blocks: JSONB // Array of blocks to analyze
}

// Check analysis status
GET /rest/v1/diary_entries?select=ai_analysis_status,ai_analysis_error&id=eq.{entry_id}

// Get cached analysis result
GET /rest/v1/ai_analysis_cache?select=*&content_hash=eq.{hash}
```

### Images
```typescript
// Upload image (get presigned URL)
POST /functions/v1/storage/upload-url
Body: {
  filename: string,
  contentType: string,
  entryId: string
}

// Delete image
DELETE /storage/v1/object/public/images/{filename}
```

### Popular Food Items
```typescript
// Get popular items
GET /rest/v1/popular_food_items?select=*&or=(user_id.eq.{user_id},user_id.is.null)&order=usage_count.desc&limit=20

// Create/update popular item
POST /rest/v1/popular_food_items
Body: {
  name: string,
  calories: number,
  protein?: number,
  fat?: number,
  carbs?: number
}
```

## Edge Functions

### Apple Sign-In Integration
```typescript
// supabase/functions/auth/apple-signin/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const { identityToken, authorizationCode, user } = await req.json()
  
  // Verify Apple ID token
  const appleUser = await verifyAppleToken(identityToken)
  
  // Create or update Supabase user
  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
  
  const { data: authUser, error } = await supabase.auth.admin.createUser({
    email: user.email,
    user_metadata: {
      apple_id: user.id,
      name: user.name
    }
  })
  
  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 400 })
  }
  
  // Create user profile
  await supabase.from('user_profiles').upsert({
    id: authUser.user.id,
    email: user.email,
    name: user.name,
    apple_id: user.id
  })
  
  // Generate custom JWT
  const token = await supabase.auth.admin.generateLink({
    type: 'magiclink',
    email: user.email
  })
  
  return new Response(JSON.stringify({ token: token.data.properties.action_link }))
})
```

### AI Analysis (Simplified)
```typescript
// supabase/functions/ai/analyze/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { Configuration, OpenAIApi } from 'https://esm.sh/openai@3.3.0'

serve(async (req) => {
  const { entryId, blocks } = await req.json()
  
  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
  
  // Update status to processing
  await supabase.from('diary_entries').update({
    ai_analysis_status: 'processing'
  }).eq('id', entryId)
  
  try {
    const openai = new OpenAIApi(new Configuration({
      apiKey: Deno.env.get('OPENAI_API_KEY')
    }))
    
    // Process each block
    const updatedBlocks = []
    for (const block of blocks) {
      // Check cache first
      const contentHash = await generateHash(block.content)
      const { data: cached } = await supabase
        .from('ai_analysis_cache')
        .select('*')
        .eq('content_hash', contentHash)
        .single()
      
      if (cached) {
        // Use cached result
        updatedBlocks.push({
          ...block,
          calories: cached.analysis_result.calories,
          protein: cached.analysis_result.protein,
          fat: cached.analysis_result.fat,
          carbs: cached.analysis_result.carbs,
          confidence: cached.confidence,
          ai_analysis: cached.analysis_result
        })
      } else {
        // Analyze with OpenAI
        const completion = await openai.createChatCompletion({
          model: "gpt-4",
          messages: [{
            role: "system",
            content: "You are a nutrition expert. Analyze the food description and return nutritional information in JSON format with calories, protein, fat, carbs, fiber, sugar, sodium, and confidence score (0-1)."
          }, {
            role: "user",
            content: block.content
          }],
          temperature: 0.3
        })
        
        const analysis = JSON.parse(completion.data.choices[0].message?.content || '{}')
        
        // Cache the result
        await supabase.from('ai_analysis_cache').insert({
          content_hash: contentHash,
          content: block.content,
          analysis_result: analysis,
          confidence: analysis.confidence || 0.0
        })
        
        updatedBlocks.push({
          ...block,
          calories: analysis.calories,
          protein: analysis.protein,
          fat: analysis.fat,
          carbs: analysis.carbs,
          fiber: analysis.fiber,
          sugar: analysis.sugar,
          sodium: analysis.sodium,
          confidence: analysis.confidence,
          ai_analysis: analysis
        })
      }
    }
    
    // Update diary entry with results
    await supabase.from('diary_entries').update({
      blocks: updatedBlocks,
      ai_analysis_status: 'completed'
    }).eq('id', entryId)
    
  } catch (error) {
    await supabase.from('diary_entries').update({
      ai_analysis_status: 'failed',
      ai_analysis_error: error.message
    }).eq('id', entryId)
  }
  
  return new Response(JSON.stringify({ success: true }))
})
```

### Image Upload URL
```typescript
// supabase/functions/storage/upload-url/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const { filename, contentType, entryId } = await req.json()
  
  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
  
  const { data, error } = await supabase.storage
    .from('images')
    .createSignedUploadUrl(filename)
  
  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 400 })
  }
  
  return new Response(JSON.stringify({ 
    uploadUrl: data.signedUrl,
    path: data.path
  }))
})
```

## TypeScript Types

### Generated Types
```typescript
// Generated by: supabase gen types typescript --local > types.ts
export interface Database {
  public: {
    Tables: {
      user_profiles: {
        Row: {
          id: string
          email: string | null
          name: string | null
          apple_id: string | null
          daily_calorie_goal: number | null
          daily_protein_goal: number | null
          daily_fat_goal: number | null
          daily_carb_goal: number | null
          units: string | null
          timezone_offset: number | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id: string
          email?: string | null
          name?: string | null
          apple_id?: string | null
          daily_calorie_goal?: number | null
          daily_protein_goal?: number | null
          daily_fat_goal?: number | null
          daily_carb_goal?: number | null
          units?: string | null
          timezone_offset?: number | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          email?: string | null
          name?: string | null
          apple_id?: string | null
          daily_calorie_goal?: number | null
          daily_protein_goal?: number | null
          daily_fat_goal?: number | null
          daily_carb_goal?: number | null
          units?: string | null
          timezone_offset?: number | null
          created_at?: string
          updated_at?: string
        }
      }
      diary_entries: {
        Row: {
          id: string
          user_id: string
          date: string
          content: string
          blocks: Json
          total_calories: number | null
          total_protein: number | null
          total_fat: number | null
          total_carbs: number | null
          total_fiber: number | null
          total_sugar: number | null
          total_sodium: number | null
          ai_analysis_status: string
          ai_analysis_error: string | null
          images: string[]
          created_at: string | null
          updated_at: string | null
        }
        Insert: {
          id?: string
          user_id: string
          date: string
          content?: string
          blocks?: Json
          total_calories?: number | null
          total_protein?: number | null
          total_fat?: number | null
          total_carbs?: number | null
          total_fiber?: number | null
          total_sugar?: number | null
          total_sodium?: number | null
          ai_analysis_status?: string
          ai_analysis_error?: string | null
          images?: string[]
          created_at?: string | null
          updated_at?: string | null
        }
        Update: {
          id?: string
          user_id?: string
          date?: string
          content?: string
          blocks?: Json
          total_calories?: number | null
          total_protein?: number | null
          total_fat?: number | null
          total_carbs?: number | null
          total_fiber?: number | null
          total_sugar?: number | null
          total_sodium?: number | null
          ai_analysis_status?: string
          ai_analysis_error?: string | null
          images?: string[]
          created_at?: string | null
          updated_at?: string | null
        }
      }
      // ... other tables
    }
  }
}
```

## Frontend Integration (Swift)

### Supabase Client Setup
```swift
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    private let client: SupabaseClient
    
    private init() {
        let supabaseURL = "YOUR_SUPABASE_URL"
        let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"
        
        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseAnonKey
        )
    }
    
    // Authentication
    func signInWithApple(identityToken: String) async throws -> User {
        let response = try await client.functions.invoke(
            function: "auth/apple-signin",
            invokeOptions: .init(body: [
                "identityToken": identityToken
            ])
        )
        
        // Handle response and set session
        return try response.decoded(to: User.self)
    }
    
    // Diary entries (simplified)
    func getDiaryEntries(dateFrom: Date, dateTo: Date) async throws -> [DiaryEntry] {
        let response = try await client
            .from("diary_entries")
            .select()
            .gte("date", value: dateFrom)
            .lte("date", value: dateTo)
            .order("date", ascending: false)
            .execute()
        
        return try response.decoded(to: [DiaryEntry].self)
    }
    
    // Update diary content
    func updateDiaryContent(entryId: String, content: String) async throws {
        try await client
            .from("diary_entries")
            .update(["content": content])
            .eq("id", value: entryId)
            .execute()
    }
    
    // Real-time subscriptions
    func subscribeToEntries() -> RealtimeChannel {
        return client.channel("diary_entries")
            .on("postgres_changes", filter: .init(event: .all, schema: "public", table: "diary_entries")) { payload in
                // Handle real-time updates
            }
            .subscribe()
    }
}
```

## Error Handling

### Standard Error Format
```typescript
{
  error: string,
  message: string,
  code: number,
  details?: object,
  traceId?: string // for log correlation
}
```

### Common Error Codes
- `400`: Bad Request (validation errors)
- `401`: Unauthorized (invalid/missing token)
- `403`: Forbidden (RLS policy violation)
- `404`: Not Found
- `409`: Conflict (sync conflicts)
- `429`: Rate Limited
- `500`: Internal Server Error

## Performance & Security

### Rate Limiting
- **API calls**: 1000 requests per minute per user
- **AI analysis**: 10 requests per minute per user
- **Image uploads**: 50 uploads per hour per user

### Caching Strategy
- **Client-side**: Cache diary entries locally with offline sync
- **Server-side**: AI analysis cache for repeated content
- **CDN**: Supabase Storage with CloudFront for images

### Security Measures
- **Row Level Security**: All tables protected by RLS policies
- **Input validation**: Validate all inputs at Edge Function level
- **Image scanning**: Scan uploaded images for malware
- **Data encryption**: Encrypt sensitive data at rest

## Development Phases

### Phase 1: Core MVP (Week 1-2)
- [x] Set up Supabase project and local development
- [x] Implement simplified database schema with RLS policies
- [ ] Create Apple Sign-In Edge Function
- [ ] Basic CRUD for diary entries
- [ ] Simple text-based calorie analysis

### Phase 2: AI Integration (Week 3-4)
- [ ] Implement async AI analysis Edge Function
- [ ] Image upload with presigned URLs
- [ ] Real-time updates for analysis results
- [ ] Popular food items functionality

### Phase 3: Polish & Optimization (Week 5-6)
- [ ] Offline sync capabilities
- [ ] Performance optimization
- [ ] Error handling and retry logic
- [ ] Analytics and insights

### Phase 4: Production Ready (Week 7-8)
- [ ] Monitoring and alerting
- [ ] Rate limiting and security hardening
- [ ] Documentation and testing
- [ ] Production deployment

## Local Development Setup

### Prerequisites
```bash
# Install Supabase CLI
npm install -g supabase

# Install Deno (for Edge Functions)
curl -fsSL https://deno.land/install.sh | sh
```

### Local Development
```bash
# Initialize Supabase project
supabase init

# Start local development environment
supabase start

# Generate types
supabase gen types typescript --local > types.ts

# Deploy Edge Functions
supabase functions deploy auth/apple-signin
supabase functions deploy ai/analyze
supabase functions deploy storage/upload-url
```

### Environment Variables
```bash
# .env.local
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
OPENAI_API_KEY=your-openai-key
```

## Deployment

### Production Setup
1. **Create Supabase project** in production
2. **Deploy schema** using migrations
3. **Deploy Edge Functions** to production
4. **Configure environment variables**
5. **Set up monitoring** and alerting

### Monitoring
- **Supabase Dashboard**: Database performance and usage
- **Edge Function logs**: Function execution and errors
- **Custom metrics**: User engagement and AI usage

This simplified Supabase-based approach provides a production-ready backend with minimal development overhead, perfect for a solo developer launching an MVP. The unified diary entries design eliminates complexity while maintaining all functionality. 