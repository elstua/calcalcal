#!/usr/bin/env node

/**
 * Test script to validate streaks functionality
 * This script creates test data and validates streak calculation
 */

const axios = require('axios');

const BASE_URL = 'http://localhost:3000';
let testUserId = null;
let authToken = null;

// Test user credentials
const TEST_USER = {
  email: 'streaks-test@example.com',
  password: 'testpassword123'
};

async function makeRequest(method, endpoint, data = null, headers = {}) {
  try {
    const config = {
      method,
      url: `${BASE_URL}${endpoint}`,
      headers: {
        'Content-Type': 'application/json',
        ...headers
      }
    };
    
    if (data) {
      config.data = data;
    }
    
    const response = await axios(config);
    return { success: true, data: response.data, status: response.status };
  } catch (error) {
    return { 
      success: false, 
      error: error.response?.data || error.message, 
      status: error.response?.status || 500
    };
  }
}

async function createTestUser() {
  console.log('🔧 Creating test user...');
  
  // Create temporary account for testing
  const deviceId = 'test-streaks-device-' + Date.now();
  const result = await makeRequest('POST', '/api/auth/create-temporary', {
    deviceId: deviceId
  });
  
  if (result.success) {
    testUserId = result.data.user.id;
    authToken = result.data.session.access_token;
    console.log(`✅ Test user created: ${testUserId}`);
    return true;
  } else {
    console.error('❌ Failed to create test user:', result.error);
    return false;
  }
}

async function getStreaks() {
  console.log('📊 Getting current streaks...');
  
  const result = await makeRequest('GET', '/api/streaks', null, {
    'Authorization': `Bearer ${authToken}`
  });
  
  if (result.success) {
    console.log('✅ Current streaks:', JSON.stringify(result.data, null, 2));
    return result.data;
  } else {
    console.error('❌ Failed to get streaks:', result.error);
    return null;
  }
}

async function createDiaryEntry(date, content, blocks = []) {
  console.log(`📝 Creating diary entry for ${date}...`);
  
  const result = await makeRequest('POST', '/api/diary/entries', {
    date,
    content,
    blocks,
    total_calories: Math.floor(Math.random() * 500) + 200
  }, {
    'Authorization': `Bearer ${authToken}`
  });
  
  if (result.success) {
    console.log(`✅ Diary entry created for ${date}`);
    return true;
  } else {
    console.error(`❌ Failed to create diary entry for ${date}:`, result.error);
    return false;
  }
}

async function testStreakCalculation() {
  console.log('\n🧪 Testing streak calculation logic...');
  
  // Get today's date and create entries for the last 5 days
  const today = new Date();
  const entries = [];
  
  // Create entries for 5 consecutive days (should result in streak of 5)
  for (let i = 4; i >= 0; i--) {
    const date = new Date(today);
    date.setDate(date.getDate() - i);
    const dateStr = date.toISOString().split('T')[0];
    
    const content = `Day ${5-i} of my healthy eating journey. Had a great salad for lunch and grilled chicken for dinner.`;
    
    entries.push({ date: dateStr, content });
  }
  
  // Create the entries
  for (const entry of entries) {
    await createDiaryEntry(entry.date, entry.content);
  }
  
  // Wait a moment for triggers to process
  await new Promise(resolve => setTimeout(resolve, 1000));
  
  // Check streaks after creating consecutive entries
  const streaksAfter = await getStreaks();
  
  if (streaksAfter && streaksAfter.currentStreak === 5) {
    console.log('✅ Streak calculation test PASSED: Expected 5, got', streaksAfter.currentStreak);
    return true;
  } else {
    console.log('❌ Streak calculation test FAILED: Expected 5, got', streaksAfter?.currentStreak);
    return false;
  }
}

async function testStreakBreak() {
  console.log('\n🧪 Testing streak break logic...');
  
  // Skip a day (yesterday) to break the streak
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 6); // Skip one day in the sequence
  const yesterdayStr = yesterday.toISOString().split('T')[0];
  
  // Create an entry with no meaningful content (placeholder)
  await createDiaryEntry(yesterdayStr, 'What did you eat today?');
  
  // Wait for triggers
  await new Promise(resolve => setTimeout(resolve, 1000));
  
  // Check streaks - should be reset
  const streaksAfterBreak = await getStreaks();
  
  if (streaksAfterBreak && streaksAfterBreak.currentStreak === 0) {
    console.log('✅ Streak break test PASSED: Expected 0, got', streaksAfterBreak.currentStreak);
    return true;
  } else {
    console.log('❌ Streak break test FAILED: Expected 0, got', streaksAfterBreak?.currentStreak);
    return false;
  }
}

async function testStreakHistory() {
  console.log('\n🧪 Testing streak history...');
  
  const result = await makeRequest('GET', '/api/streaks/history', null, {
    'Authorization': `Bearer ${authToken}`
  });
  
  if (result.success) {
    console.log('✅ Streak history:', JSON.stringify(result.data, null, 2));
    return true;
  } else {
    console.error('❌ Failed to get streak history:', result.error);
    return false;
  }
}

async function testStreakStatistics() {
  console.log('\n🧪 Testing streak statistics...');
  
  const result = await makeRequest('GET', '/api/streaks/statistics', null, {
    'Authorization': `Bearer ${authToken}`
  });
  
  if (result.success) {
    console.log('✅ Streak statistics:', JSON.stringify(result.data, null, 2));
    return true;
  } else {
    console.error('❌ Failed to get streak statistics:', result.error);
    return false;
  }
}

async function testRecalculation() {
  console.log('\n🧪 Testing streak recalculation...');
  
  const result = await makeRequest('POST', '/api/streaks/recalculate', null, {
    'Authorization': `Bearer ${authToken}`
  });
  
  if (result.success) {
    console.log('✅ Recalculation result:', JSON.stringify(result.data, null, 2));
    return true;
  } else {
    console.error('❌ Failed to recalculate streaks:', result.error);
    return false;
  }
}

async function cleanup() {
  console.log('\n🧹 Cleaning up test data...');
  
  if (testUserId) {
    // Delete the test user
    const result = await makeRequest('DELETE', '/api/auth/delete-account', null, {
      'Authorization': `Bearer ${authToken}`
    });
    
    if (result.success) {
      console.log('✅ Test user deleted successfully');
    } else {
      console.error('❌ Failed to delete test user:', result.error);
    }
  }
}

async function runTests() {
  console.log('🚀 Starting streaks functionality tests...\n');
  
  const results = {
    userCreation: false,
    streakCalculation: false,
    streakBreak: false,
    streakHistory: false,
    streakStatistics: false,
    recalculation: false
  };
  
  try {
    // Create test user
    results.userCreation = await createTestUser();
    
    if (!results.userCreation) {
      throw new Error('Failed to create test user');
    }
    
    // Test initial streaks (should be 0)
    await getStreaks();
    
    // Test streak calculation with consecutive entries
    results.streakCalculation = await testStreakCalculation();
    
    // Test streak break
    results.streakBreak = await testStreakBreak();
    
    // Test streak history
    results.streakHistory = await testStreakHistory();
    
    // Test streak statistics
    results.streakStatistics = await testStreakStatistics();
    
    // Test recalculation
    results.recalculation = await testRecalculation();
    
  } catch (error) {
    console.error('❌ Test execution failed:', error.message);
  } finally {
    // Cleanup
    await cleanup();
    
    // Print results summary
    console.log('\n📊 Test Results Summary:');
    console.log('========================');
    Object.entries(results).forEach(([test, passed]) => {
      console.log(`${passed ? '✅' : '❌'} ${test}: ${passed ? 'PASSED' : 'FAILED'}`);
    });
    
    const passedTests = Object.values(results).filter(Boolean).length;
    const totalTests = Object.keys(results).length;
    
    console.log(`\n🎯 Overall: ${passedTests}/${totalTests} tests passed`);
    
    if (passedTests === totalTests) {
      console.log('🎉 All tests passed! Streaks functionality is working correctly.');
    } else {
      console.log('⚠️  Some tests failed. Please check the implementation.');
    }
  }
}

// Run the tests
runTests().catch(console.error);