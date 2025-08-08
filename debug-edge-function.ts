import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { jwtVerify } from 'https://esm.sh/jose@4.15.4'

interface AppleSignInRequest {
  identityToken: string
  authorizationCode?: string
  user: {
    id: string
    email?: string
    name?: string
  }
}

interface AppleSignInResponse {
  success: boolean
  user?: {
    id: string
    email?: string
    name?: string
    daily_calorie_goal?: number
    daily_protein_goal?: number
    daily_fat_goal?: number
    daily_carb_goal?: number
    units?: string
    timezone_offset?: number
    created_at?: string
    updated_at?: string
  }
  session?: {
    access_token: string
    refresh_token: string
    expires_in: number
  }
  error?: string
}

// Apple's public keys for JWT verification
const APPLE_PUBLIC_KEYS_URL = 'https://appleid.apple.com/auth/keys'

// Cache for Apple's public keys
let applePublicKeys: any = null
let keysLastFetched = 0
const KEYS_CACHE_DURATION = 24 * 60 * 60 * 1000 // 24 hours

async function getApplePublicKeys() {
  const now = Date.now()
  
  // Return cached keys if still valid
  if (applePublicKeys && (now - keysLastFetched) < KEYS_CACHE_DURATION) {
    return applePublicKeys
  }
  
  try {
    const response = await fetch(APPLE_PUBLIC_KEYS_URL)
    const data = await response.json()
    applePublicKeys = data
    keysLastFetched = now
    return data
  } catch (error) {
    console.error('Failed to fetch Apple public keys:', error)
    throw new Error('Failed to verify Apple ID token')
  }
}

async function verifyAppleToken(identityToken: string): Promise<any> {
  try {
    // Decode the JWT header to get the key ID
    const [headerB64] = identityToken.split('.')
    const header = JSON.parse(atob(headerB64))
    const keyId = header.kid
    
    // Get Apple's public keys
    const keys = await getApplePublicKeys()
    const publicKey = keys.keys.find((key: any) => key.kid === keyId)
    
    if (!publicKey) {
      throw new Error('Apple public key not found')
    }
    
    // Convert JWK to PEM format
    const jwk = {
      kty: publicKey.kty,
      kid: publicKey.kid,
      use: publicKey.use,
      alg: publicKey.alg,
      n: publicKey.n,
      e: publicKey.e
    }
    
    // Verify the token
    const { payload } = await jwtVerify(identityToken, jwk as any, {
      issuer: 'https://appleid.apple.com',
      audience: Deno.env.get('APPLE_CLIENT_ID') || 'com.calycal.app', // Your app's bundle ID
      algorithms: ['RS256']
    })
    
    return payload
  } catch (error) {
    console.error('Apple token verification failed:', error)
    throw new Error('Invalid Apple ID token')
  }
}

serve(async (req) => {
  console.log('🔍 === EDGE FUNCTION DEBUG ===')
  console.log('Request method:', req.method)
  console.log('Request URL:', req.url)
  console.log('Request headers:', Object.fromEntries(req.headers.entries()))
  
  // Handle CORS
  if (req.method === 'OPTIONS') {
    console.log('Handling CORS preflight request')
    return new Response(null, {
      status: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      }
    })
  }
  
  if (req.method !== 'POST') {
    console.log('❌ Method not allowed:', req.method)
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' }
    })
  }
  
  // Check for authorization header
  const authHeader = req.headers.get('Authorization')
  console.log('🔑 Authorization header received:', authHeader)
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    console.log('❌ Missing or invalid authorization header')
    return new Response(JSON.stringify({ 
      success: false, 
      error: 'Missing authorization header' 
    }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' }
    })
  }
  
  // Extract token
  const token = authHeader.substring(7) // Remove 'Bearer ' prefix
  console.log('🔐 Token received (first 20 chars):', token.substring(0, 20) + '...')
  console.log('🔐 Token length:', token.length)
  
  // Get expected anon key
  const expectedAnonKey = Deno.env.get('SUPABASE_ANON_KEY')
  console.log('🔑 Expected anon key (first 20 chars):', expectedAnonKey?.substring(0, 20) + '...')
  console.log('🔑 Expected anon key length:', expectedAnonKey?.length)
  
  // Compare tokens
  console.log('🔍 Token comparison:')
  console.log('   - Tokens match:', token === expectedAnonKey)
  console.log('   - Token starts with expected:', token.startsWith(expectedAnonKey?.substring(0, 20) || ''))
  
  if (token !== expectedAnonKey) {
    console.log('❌ Invalid authorization token')
    return new Response(JSON.stringify({ 
      success: false, 
      error: 'Invalid authorization token' 
    }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' }
    })
  }
  
  console.log('✅ Authorization token validated successfully')
  
  try {
    const body = await req.text()
    console.log('📦 Request body received:', body)
    
    const { identityToken, authorizationCode, user }: AppleSignInRequest = JSON.parse(body)
    
    console.log('📋 Parsed request data:')
    console.log('   - Identity token (first 20 chars):', identityToken?.substring(0, 20) + '...')
    console.log('   - User ID:', user?.id)
    console.log('   - User email:', user?.email)
    console.log('   - User name:', user?.name)
    
    if (!identityToken || !user?.id) {
      console.log('❌ Missing required parameters')
      return new Response(JSON.stringify({ 
        success: false, 
        error: 'Missing required parameters' 
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      })
    }
    
    console.log('🔍 === END EDGE FUNCTION DEBUG ===')
    
    // Continue with the rest of your existing logic...
    // (I'll stop here for debugging purposes)
    
    return new Response(JSON.stringify({ 
      success: true, 
      message: 'Debug mode - authorization successful' 
    }), {
      status: 200,
      headers: { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    })
    
  } catch (error) {
    console.error('❌ Error in request processing:', error)
    
    return new Response(JSON.stringify({ 
      success: false, 
      error: error instanceof Error ? error.message : 'Authentication failed' 
    }), {
      status: 500,
      headers: { 
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    })
  }
}) 