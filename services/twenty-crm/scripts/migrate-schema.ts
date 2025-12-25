import axios from 'axios';
import * as fs from 'fs';

// ==================== Configuration ====================
// CRITICAL FIX: Read from .env file FIRST, before checking environment variables
// This ensures we get the token even if it wasn't passed as env var

let TWENTY_ADMIN_TOKEN = '';
let BOOTSTRAP_SECRET = '';

// Step 1: Try to read from .env file first (most reliable in Docker)
function readFromEnvFile() {
  const envPaths = [
    '/app/.env',
    '/opt/twenty-crm-production/.env',
    '/app/scripts/../../.env',
    '/app/scripts/../.env',
    '.env'
  ];

  for (const envPath of envPaths) {
    try {
      if (fs.existsSync(envPath)) {
        const envContent = fs.readFileSync(envPath, 'utf8');
        
        // Read TWENTY_ADMIN_TOKEN
        const tokenMatch = envContent.match(/^TWENTY_ADMIN_TOKEN=(.+)$/m);
        if (tokenMatch && tokenMatch[1]) {
          const token = tokenMatch[1].trim().replace(/^["']|["']$/g, '');
          if (token.length > 20) {
            TWENTY_ADMIN_TOKEN = token;
            console.log(`📄 Read TWENTY_ADMIN_TOKEN from ${envPath} (length: ${token.length})`);
          }
        }
        
        // Read BOOTSTRAP_SECRET
        const secretMatch = envContent.match(/^BOOTSTRAP_SECRET=(.+)$/m);
        if (secretMatch && secretMatch[1]) {
          const secret = secretMatch[1].trim().replace(/^["']|["']$/g, '');
          BOOTSTRAP_SECRET = secret;
        }
        
        // If we found the token, we can stop searching
        if (TWENTY_ADMIN_TOKEN.length > 20) {
          break;
        }
      }
    } catch (error) {
      // Continue to next path
    }
  }
}

// Step 2: Override with environment variables if they're set (env vars take precedence)
readFromEnvFile();

const TWENTY_API_KEY = process.env.TWENTY_API_KEY || process.env.APP_SECRET || '';
const TWENTY_BASE_URL = process.env.TWENTY_BASE_URL || process.env.SERVER_URL || 'http://localhost:3000';

// Override from environment if set
if (process.env.TWENTY_ADMIN_TOKEN && process.env.TWENTY_ADMIN_TOKEN.length > 20) {
  TWENTY_ADMIN_TOKEN = process.env.TWENTY_ADMIN_TOKEN;
  console.log(`📌 Using TWENTY_ADMIN_TOKEN from environment (length: ${TWENTY_ADMIN_TOKEN.length})`);
}

if (process.env.BOOTSTRAP_SECRET) {
  BOOTSTRAP_SECRET = process.env.BOOTSTRAP_SECRET;
}

// Check if we have an API token (preferred method)
const hasApiToken = Boolean(TWENTY_ADMIN_TOKEN.length > 20 || TWENTY_API_KEY.length > 20);

// Only use bootstrap mode if we don't have an API token
// (Bootstrap mode requires server-side support which we don't have)
const isBootstrapMode = Boolean(BOOTSTRAP_SECRET.length > 0 && !hasApiToken);

console.log('\n🔐 Authentication Configuration:');
console.log(`   TWENTY_ADMIN_TOKEN: ${TWENTY_ADMIN_TOKEN.length > 0 ? `SET (${TWENTY_ADMIN_TOKEN.length} chars)` : 'NOT SET'}`);
console.log(`   BOOTSTRAP_SECRET: ${BOOTSTRAP_SECRET.length > 0 ? 'SET' : 'NOT SET'}`);
console.log(`   API Token Available: ${hasApiToken ? '✅ YES' : '❌ NO'}`);
console.log(`   Bootstrap Mode: ${isBootstrapMode ? '🔧 ENABLED' : '❌ DISABLED'}`);

if (isBootstrapMode) {
  console.log('\n⚠️  WARNING: Bootstrap mode is enabled');
  console.log('   This requires server-side middleware support!');
  console.log('   If server returns "Forbidden resource", bootstrap mode is not supported.');
} else if (hasApiToken) {
  console.log('\n✅ API token authentication will be used');
} else {
  console.error('\n❌ ERROR: No authentication method available!');
  console.error('   Set TWENTY_ADMIN_TOKEN in .env file or environment');
  process.exit(1);
}

// Wait for server to be ready
async function waitForServer(maxAttempts = 60, delay = 2000) {
  for (let i = 0; i < maxAttempts; i++) {
    try {
      const response = await axios.get(`${TWENTY_BASE_URL}/health`, { timeout: 5000 });
      if (response.status === 200) {
        console.log('✅ Server is ready');
        return true;
      }
    } catch (error) {
      if (i < maxAttempts - 1) {
        if (i % 10 === 0) {
          console.log(`⏳ Waiting for server... (${i + 1}/${maxAttempts})`);
        }
        await new Promise<void>(resolve => setTimeout(resolve, delay));
      }
    }
  }
  console.log('⚠️  Server not ready, proceeding anyway...');
  return false;
}

// ==================== Authentication Helper ====================
let authToken: string | null = null;

async function authenticate(): Promise<string> {
  // Return cached token if available
  if (authToken) {
    return authToken;
  }

  // Bootstrap mode: return dummy token (server will check X-Bootstrap-Secret header)
  if (isBootstrapMode) {
    console.log('🔧 Bootstrap mode: Using dummy token (server checks X-Bootstrap-Secret header)');
    authToken = 'bootstrap-dummy-token';
    return authToken;
  }

  // Use the token we already loaded from .env or environment
  if (TWENTY_ADMIN_TOKEN && TWENTY_ADMIN_TOKEN.length > 20) {
    console.log(`✅ Using API token (length: ${TWENTY_ADMIN_TOKEN.length})`);
    authToken = TWENTY_ADMIN_TOKEN;
    return authToken;
  }

  // If no token provided, fail with clear error
  console.error('⚠️  No API token found. Migration cannot proceed.');
  console.error('   Set TWENTY_ADMIN_TOKEN in .env file to enable automatic object creation.');
  throw new Error('TWENTY_ADMIN_TOKEN is required for migration.');
}

// ==================== GraphQL Client ====================
const graphqlClient = axios.create({
  baseURL: TWENTY_BASE_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Add request interceptor to inject auth token or bootstrap secret
graphqlClient.interceptors.request.use(async (config) => {
  if (isBootstrapMode) {
    // Bootstrap mode: use X-Bootstrap-Secret header instead of Authorization
    config.headers['X-Bootstrap-Secret'] = BOOTSTRAP_SECRET;
    if (config.url?.includes('/metadata')) {
      console.log('🔧 Using X-Bootstrap-Secret header for authentication bypass');
    }
  } else {
    // Normal mode: use Bearer token
    const token = await authenticate();
    if (token) {
      config.headers['Authorization'] = `Bearer ${token}`;
    }
  }
  return config;
});

// Add response interceptor for better error handling
graphqlClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      console.error('🔒 Token expired or invalid. Re-authenticating...');
      authToken = null; // Clear token to force re-auth
    }
    return Promise.reject(error);
  }
);

async function graphql(query: string, variables: Record<string, any> = {}) {
  try {
    const response = await graphqlClient.post('/metadata', {
      query,
      variables,
    });
    
    if (response.data.errors) {
      console.error('❌ GraphQL Errors:', JSON.stringify(response.data.errors, null, 2));
      throw new Error(`GraphQL Error: ${response.data.errors[0].message}`);
    }
    
    return response.data.data;
  } catch (error: any) {
    console.error('❌ GraphQL request failed:', error.message);
    if (error.response?.data) {
      console.error('   Response:', JSON.stringify(error.response.data, null, 2));
    }
    throw error;
  }
}

// ==================== Migration Steps ====================

async function main() {
  console.log('\n🚀 Starting Twenty CRM Data Model Migration...\n');
  
  // Wait for server to be ready
  const isReady = await waitForServer();
  if (!isReady) {
    console.error('❌ Server not ready. Aborting migration.');
    process.exit(1);
  }
  
  // Ensure we have authentication
  let authenticated = false;
  try {
    // Test authentication with a simple query
    await graphql(`query { objects(paging: { first: 1 }) { edges { node { id } } } }`);
    authenticated = true;
    console.log('✅ Successfully authenticated with Twenty CRM\n');
  } catch (error: any) {
    console.error('\n❌ Authentication failed. Please check:');
    console.error('   1. TWENTY_ADMIN_TOKEN is set in .env file');
    console.error('   2. Token is valid and not expired');
    console.error('   3. Ensure the backend server is fully started\n');
    console.error('Error details:', error.message);
    process.exit(1);
  }

  // Execute in order
  await createCustomObjects();
  await extendExistingObjects();
  await createRelationships();
  await verifyMigration();

  console.log('\n🎉 Migration completed successfully!');
  console.log('\nNext steps:');
  console.log('1. Review the verification report above');
  console.log('2. Test the 10 workflow automations');
  console.log('3. Configure your Salla and ElevenLabs integrations');
}

// ==================== Step 1: Create Custom Objects ====================
async function createCustomObjects() {
  console.log('📦 Step 1: Creating 7 Custom Objects with Fields...\n');

  const objects = [
    {
      nameSingular: 'agentSetting',
      namePlural: 'agentSettings',
      labelSingular: 'Agent Setting',
      labelPlural: 'Agent Settings',
      description: 'ElevenLabs agent configuration and settings',
      icon: 'IconRobot',
      fields: [
        { name: 'agentId', type: 'TEXT', label: 'ElevenLabs Agent ID' },
        { name: 'apiKey', type: 'TEXT', label: 'API Key (Encrypted)', isRequired: true },
        { name: 'storeName', type: 'TEXT', label: 'Salla Store Name', isRequired: true },
        { name: 'voiceId', type: 'TEXT', label: 'Voice ID' },
        { name: 'modelConfig', type: 'RAW_JSON', label: 'Model Configuration' },
        { name: 'isActive', type: 'BOOLEAN', label: 'Active', defaultValue: false },
        { name: 'callCount', type: 'NUMBER', label: 'Total Calls', defaultValue: 0 },
        { name: 'successRate', type: 'NUMBER', label: 'Success Rate (%)', defaultValue: 0 },
        { name: 'lastCallAt', type: 'DATE_TIME', label: 'Last Call Date' },
        { name: 'widgetPrimaryColor', type: 'TEXT', label: 'Widget Primary Color', defaultValue: '#2563eb' },
        { name: 'autoCallEnabled', type: 'BOOLEAN', label: 'Auto-Call Enabled', defaultValue: true },
        { name: 'callTriggers', type: 'RAW_JSON', label: 'Call Triggers (JSON)', defaultValue: JSON.stringify(['abandoned_cart', 'high_value_lead']) },
      ]
    },
    {
      nameSingular: 'sallaProduct',
      namePlural: 'sallaProducts',
      labelSingular: 'Salla Product',
      labelPlural: 'Salla Products',
      description: 'Products synced from Salla',
      icon: 'IconShoppingCart',
      fields: [
        { name: 'sallaProductId', type: 'TEXT', label: 'Salla Product ID', isRequired: true, isUnique: true },
        { name: 'name', type: 'TEXT', label: 'Product Name', isRequired: true },
        { name: 'description', type: 'TEXT', label: 'Description' },
        { name: 'price', type: 'NUMBER', label: 'Price (SAR)', isRequired: true },
        { name: 'comparePrice', type: 'NUMBER', label: 'Compare at Price' },
        { name: 'stockQuantity', type: 'NUMBER', label: 'Stock Quantity', defaultValue: 0 },
        { name: 'sku', type: 'TEXT', label: 'SKU' },
        { name: 'barcode', type: 'TEXT', label: 'Barcode' },
        { name: 'mainImage', type: 'TEXT', label: 'Main Image URL' },
        { name: 'images', type: 'RAW_JSON', label: 'Images (JSON Array)' },
        { name: 'imageAlt', type: 'TEXT', label: 'Image Alt Text' },
        { name: 'status', type: 'SELECT', label: 'Status', options: ['ACTIVE', 'DRAFT', 'ARCHIVED'], defaultValue: 'ACTIVE' },
        { name: 'isFeatured', type: 'BOOLEAN', label: 'Featured Product', defaultValue: false },
        { name: 'categories', type: 'RAW_JSON', label: 'Categories (IDs)' },
        { name: 'brandId', type: 'TEXT', label: 'Brand ID' },
        { name: 'weight', type: 'NUMBER', label: 'Weight (kg)' },
        { name: 'requiresShipping', type: 'BOOLEAN', label: 'Requires Shipping', defaultValue: true },
        { name: 'metaTitle', type: 'TEXT', label: 'Meta Title' },
        { name: 'metaDescription', type: 'TEXT', label: 'Meta Description' },
        { name: 'metaKeywords', type: 'TEXT', label: 'Meta Keywords' },
        { name: 'slug', type: 'TEXT', label: 'URL Slug' },
        { name: 'canonicalUrl', type: 'TEXT', label: 'Canonical URL' },
        { name: 'ogTitle', type: 'TEXT', label: 'Open Graph Title' },
        { name: 'ogDescription', type: 'TEXT', label: 'Open Graph Description' },
        { name: 'ogImage', type: 'TEXT', label: 'Open Graph Image' },
        { name: 'twitterCard', type: 'SELECT', label: 'Twitter Card Type', options: ['SUMMARY', 'SUMMARY_LARGE_IMAGE'] },
        { name: 'twitterTitle', type: 'TEXT', label: 'Twitter Title' },
        { name: 'twitterDescription', type: 'TEXT', label: 'Twitter Description' },
        { name: 'twitterImage', type: 'TEXT', label: 'Twitter Image' },
        { name: 'structuredData', type: 'RAW_JSON', label: 'Structured Data (JSON-LD)' },
      ]
    },
    {
      nameSingular: 'sallaOrder',
      namePlural: 'sallaOrders',
      labelSingular: 'Salla Order',
      labelPlural: 'Salla Orders',
      description: 'Detailed order data from Salla',
      icon: 'IconShoppingCart',
      fields: [
        { name: 'orderId', type: 'TEXT', label: 'Salla Order ID', isRequired: true, isUnique: true },
        { name: 'orderNumber', type: 'TEXT', label: 'Order Number' },
        { name: 'customer', type: 'RAW_JSON', label: 'Customer (JSON)' },
        { name: 'status', type: 'SELECT', label: 'Order Status', options: ['PENDING', 'CONFIRMED', 'COMPLETED', 'CANCELED', 'REFUNDED'], defaultValue: 'PENDING' },
        { name: 'financialStatus', type: 'SELECT', label: 'Financial Status', options: ['PAID', 'PENDING', 'REFUNDED', 'PARTIALLY_REFUNDED'] },
        { name: 'fulfillmentStatus', type: 'SELECT', label: 'Fulfillment Status', options: ['UNFULFILLED', 'PARTIAL', 'FULFILLED'] },
        { name: 'currency', type: 'TEXT', label: 'Currency', defaultValue: 'SAR' },
        { name: 'subtotal', type: 'NUMBER', label: 'Subtotal' },
        { name: 'total', type: 'NUMBER', label: 'Total' },
        { name: 'totalTax', type: 'NUMBER', label: 'Total Tax', defaultValue: 0 },
        { name: 'totalDiscount', type: 'NUMBER', label: 'Total Discount', defaultValue: 0 },
        { name: 'totalShipping', type: 'NUMBER', label: 'Shipping Cost', defaultValue: 0 },
        { name: 'lineItems', type: 'RAW_JSON', label: 'Line Items (JSON)' },
        { name: 'shippingAddress', type: 'RAW_JSON', label: 'Shipping Address' },
        { name: 'billingAddress', type: 'RAW_JSON', label: 'Billing Address' },
        { name: 'paymentMethod', type: 'TEXT', label: 'Payment Method' },
        { name: 'paymentGatewayTransactionId', type: 'TEXT', label: 'Payment Gateway Transaction ID' },
        { name: 'fulfillments', type: 'RAW_JSON', label: 'Fulfillments (JSON)' },
        { name: 'refunds', type: 'RAW_JSON', label: 'Refunds (JSON)' },
        { name: 'discountCodes', type: 'RAW_JSON', label: 'Discount Codes' },
        { name: 'orderNotes', type: 'TEXT', label: 'Order Notes' },
        { name: 'referringSite', type: 'TEXT', label: 'Referring Site' },
        { name: 'landingPage', type: 'TEXT', label: 'Landing Page' },
        { name: 'placedAt', type: 'DATE_TIME', label: 'Order Placed At', isRequired: true },
        { name: 'closedAt', type: 'DATE_TIME', label: 'Order Closed At' },
        { name: 'cancelledAt', type: 'DATE_TIME', label: 'Order Cancelled At' },
      ]
    },
    {
      nameSingular: 'sallaCart',
      namePlural: 'sallaCarts',
      labelSingular: 'Salla Cart',
      labelPlural: 'Salla Carts',
      description: 'Abandoned carts from Salla',
      icon: 'IconShoppingBag',
      fields: [
        { name: 'sallaCartId', type: 'TEXT', label: 'Salla Cart ID', isRequired: true, isUnique: true },
        { name: 'customerId', type: 'TEXT', label: 'Customer ID', isRequired: true },
        { name: 'token', type: 'TEXT', label: 'Cart Token' },
        { name: 'total', type: 'NUMBER', label: 'Total Value (SAR)' },
        { name: 'itemCount', type: 'NUMBER', label: 'Number of Items' },
        { name: 'items', type: 'RAW_JSON', label: 'Cart Items (JSON)' },
        { name: 'abandonedAt', type: 'DATE_TIME', label: 'Abandoned At' },
        { name: 'recoveryStatus', type: 'SELECT', label: 'Recovery Status', options: ['PENDING', 'CONTACTED', 'RECOVERED', 'LOST'], defaultValue: 'PENDING' },
        { name: 'source', type: 'TEXT', label: 'Abandonment Source' },
      ]
    },
    {
      nameSingular: 'voiceCall',
      namePlural: 'voiceCalls',
      labelSingular: 'Voice Call',
      labelPlural: 'Voice Calls',
      description: 'ElevenLabs AI voice calls',
      icon: 'IconPhone',
      fields: [
        { name: 'callId', type: 'TEXT', label: 'ElevenLabs Call ID', isRequired: true, isUnique: true },
        { name: 'agentId', type: 'TEXT', label: 'ElevenLabs Agent ID', isRequired: true },
        { name: 'phoneNumber', type: 'TEXT', label: 'Phone Number', isRequired: true },
        { name: 'direction', type: 'SELECT', label: 'Direction', options: ['INBOUND', 'OUTBOUND'], defaultValue: 'OUTBOUND' },
        { name: 'status', type: 'SELECT', label: 'Call Status', options: ['INITIATED', 'RINGING', 'CONNECTED', 'COMPLETED', 'FAILED', 'NO_ANSWER', 'BUSY'], defaultValue: 'INITIATED' },
        { name: 'duration', type: 'NUMBER', label: 'Duration (seconds)', defaultValue: 0 },
        { name: 'startedAt', type: 'DATE_TIME', label: 'Started At', isRequired: true },
        { name: 'endedAt', type: 'DATE_TIME', label: 'Ended At' },
        { name: 'recordingUrl', type: 'TEXT', label: 'Recording URL' },
        { name: 'transcription', type: 'TEXT', label: 'Transcription' },
        { name: 'summary', type: 'TEXT', label: 'Call Summary' },
        { name: 'sentiment', type: 'SELECT', label: 'Sentiment', options: ['POSITIVE', 'NEUTRAL', 'NEGATIVE'], defaultValue: 'NEUTRAL' },
        { name: 'intent', type: 'RAW_JSON', label: 'Intent (JSON Array)' },
        { name: 'cost', type: 'NUMBER', label: 'Call Cost (USD)', defaultValue: 0 },
      ]
    },
    {
      nameSingular: 'workflowExecution',
      namePlural: 'workflowExecutions',
      labelSingular: 'Workflow Execution',
      labelPlural: 'Workflow Executions',
      description: 'Workflow execution records',
      icon: 'IconSettingsAutomation',
      fields: [
        { name: 'workflowName', type: 'TEXT', label: 'Workflow Name' },
        { name: 'triggerId', type: 'TEXT', label: 'Trigger ID' },
        { name: 'triggerData', type: 'RAW_JSON', label: 'Trigger Data (JSON)' },
        { name: 'status', type: 'SELECT', label: 'Execution Status', options: ['PENDING', 'RUNNING', 'COMPLETED', 'FAILED', 'PAUSED'], defaultValue: 'PENDING' },
        { name: 'currentNode', type: 'TEXT', label: 'Current Node' },
        { name: 'executionPath', type: 'RAW_JSON', label: 'Execution Path (JSON Array)' },
        { name: 'startedAt', type: 'DATE_TIME', label: 'Started At', isRequired: true },
        { name: 'completedAt', type: 'DATE_TIME', label: 'Completed At' },
        { name: 'error', type: 'TEXT', label: 'Error Message' },
        { name: 'customerName', type: 'TEXT', label: 'Customer Name' },
        { name: 'customerId', type: 'TEXT', label: 'Customer ID' },
      ]
    },
    {
      nameSingular: 'communicationLog',
      namePlural: 'communicationLogs',
      labelSingular: 'Communication Log',
      labelPlural: 'Communication Logs',
      description: 'Logs of all automated communications',
      icon: 'IconMail',
      fields: [
        { name: 'channel', type: 'SELECT', label: 'Channel', options: ['CALL', 'WHATSAPP', 'EMAIL', 'SMS'], isRequired: true },
        { name: 'direction', type: 'SELECT', label: 'Direction', options: ['INBOUND', 'OUTBOUND'], defaultValue: 'OUTBOUND' },
        { name: 'status', type: 'TEXT', label: 'Status' },
        { name: 'content', type: 'TEXT', label: 'Content' },
        { name: 'metadata', type: 'RAW_JSON', label: 'Metadata (JSON)' },
        { name: 'automationId', type: 'TEXT', label: 'Automation ID' },
        { name: 'sentAt', type: 'DATE_TIME', label: 'Sent At' },
        { name: 'deliveredAt', type: 'DATE_TIME', label: 'Delivered At' },
        { name: 'readAt', type: 'DATE_TIME', label: 'Read At' },
        { name: 'response', type: 'TEXT', label: 'Response' },
      ]
    },
  ];

  // Create objects first
  for (const obj of objects) {
    try {
      const mutation = `
        mutation CreateObject($input: CreateOneObjectInput!) {
          createOneObject(input: $input) {
            id
            nameSingular
            namePlural
          }
        }
      `;

      const variables = {
        input: {
          object: {
            nameSingular: obj.nameSingular,
            namePlural: obj.namePlural,
            labelSingular: obj.labelSingular,
            labelPlural: obj.labelPlural,
            description: obj.description,
            icon: obj.icon,
          }
        }
      };

      const result = await graphql(mutation, variables);
      console.log(`✅ Created object: ${obj.labelSingular}`);
      
      // Create fields for this object
      await createFieldsForObject(obj.nameSingular, obj.fields);
    } catch (error: any) {
      if (error.message.includes('already exists') || error.message.includes('duplicate')) {
        console.log(`⏭️  Object already exists: ${obj.labelSingular}`);
        // Still try to create fields in case they're missing
        await createFieldsForObject(obj.nameSingular, obj.fields);
      } else {
        console.error(`❌ Failed to create ${obj.labelSingular}:`, error.message);
      }
    }
  }
}

// Helper function to create fields for an object
async function createFieldsForObject(objectName: string, fields: any[]) {
  for (const field of fields) {
    try {
      const fieldData: any = {
        name: field.name,
        label: field.label,
        type: field.type,
      };

      if (field.isRequired) {
        fieldData.isRequired = true;
      }
      if (field.isUnique) {
        fieldData.isUnique = true;
      }
      if (field.defaultValue !== undefined) {
        fieldData.defaultValue = field.defaultValue;
      }
      if (field.options && field.type === 'SELECT') {
        fieldData.options = field.options;
      }

      const mutation = `
        mutation CreateField($input: CreateOneFieldMetadataInput!) {
          createOneField(input: $input) {
            id
            name
          }
        }
      `;

      const variables = {
        input: {
          field: fieldData,
          objectName: objectName,
        }
      };

      await graphql(mutation, variables);
      console.log(`   ✅ Created field: ${field.label}`);
    } catch (error: any) {
      if (error.message.includes('already exists') || error.message.includes('duplicate')) {
        // Field already exists, skip
      } else {
        console.error(`   ⚠️  Failed to create field ${field.name}:`, error.message);
      }
    }
  }
}

// ==================== Step 2: Extend Existing Objects ====================
async function extendExistingObjects() {
  console.log('\n📝 Step 2: Extending Existing Objects...\n');
  
  const extensions = [
    {
      objectName: 'person',
      fields: [
        { name: 'sallaCustomerId', type: 'TEXT', label: 'Salla Customer ID' },
        { name: 'totalSpent', type: 'NUMBER', label: 'Total Spent (SAR)', defaultValue: 0 },
        { name: 'ordersCount', type: 'NUMBER', label: 'Orders Count', defaultValue: 0 },
        { name: 'lastOrderDate', type: 'DATE_TIME', label: 'Last Order Date' },
        { name: 'sallaTags', type: 'SELECT', label: 'Salla Tags', options: ['VIP', 'FREQUENT_BUYER', 'RISK', 'NEW'] },
      ]
    },
    {
      objectName: 'opportunity',
      fields: [
        { name: 'sallaOrderId', type: 'TEXT', label: 'Salla Order ID', isUnique: true },
        { name: 'cartStatus', type: 'SELECT', label: 'Cart Status', options: ['ABANDONED', 'RECOVERED', 'COMPLETED', 'PENDING'] },
        { name: 'abandonedValue', type: 'NUMBER', label: 'Abandoned Cart Value' },
        { name: 'sallaPaymentMethod', type: 'TEXT', label: 'Payment Method' },
        { name: 'sallaShippingAddress', type: 'RAW_JSON', label: 'Shipping Address (JSON)' },
      ]
    },
    {
      objectName: 'workflow',
      fields: [
        { name: 'trigger', type: 'TEXT', label: 'Trigger', isRequired: true },
        { name: 'category', type: 'SELECT', label: 'Category', options: ['STANDARD', 'CUSTOM', 'TEMPLATE'], defaultValue: 'STANDARD' },
        { name: 'status', type: 'SELECT', label: 'Status', options: ['ACTIVE', 'PAUSED', 'DRAFT'], defaultValue: 'DRAFT' },
        { name: 'graphConfig', type: 'RAW_JSON', label: 'Graph Configuration (JSON)' },
        { name: 'nodes', type: 'RAW_JSON', label: 'Workflow Nodes' },
        { name: 'edges', type: 'RAW_JSON', label: 'Workflow Edges' },
        { name: 'stateDefinition', type: 'RAW_JSON', label: 'State Definition (JSON)' },
        { name: 'isActiveWorkflow', type: 'BOOLEAN', label: 'Active Workflow', defaultValue: false },
        { name: 'executionCount', type: 'NUMBER', label: 'Total Executions', defaultValue: 0 },
        { name: 'successRate', type: 'NUMBER', label: 'Success Rate (%)', defaultValue: 0 },
        { name: 'averageDuration', type: 'NUMBER', label: 'Avg Duration (ms)', defaultValue: 0 },
        { name: 'lastExecutionAt', type: 'DATE_TIME', label: 'Last Execution' },
        { name: 'errorRate', type: 'NUMBER', label: 'Error Rate (%)', defaultValue: 0 },
        { name: 'checkpointsEnabled', type: 'BOOLEAN', label: 'Checkpoints Enabled', defaultValue: true },
        { name: 'humanInTheLoop', type: 'BOOLEAN', label: 'Human-in-the-Loop', defaultValue: true },
      ]
    },
  ];

  for (const ext of extensions) {
    console.log(`📌 Extending ${ext.objectName}...`);
    await createFieldsForObject(ext.objectName, ext.fields);
  }
}

// ==================== Step 3: Create Relationships ====================
async function createRelationships() {
  console.log('\n🔗 Step 3: Creating Relationships...\n');
  
  // First, get object IDs by querying objects list
  const getObjectId = async (objectName: string): Promise<string | null> => {
    try {
      const query = `
        query GetObjects {
          objects(paging: { first: 100 }) {
            edges {
              node {
                id
                nameSingular
              }
            }
          }
        }
      `;
      const result = await graphql(query);
      const objects = result.objects?.edges || [];
      const found = objects.find((e: any) => e.node.nameSingular === objectName);
      return found?.node?.id || null;
    } catch (error) {
      return null;
    }
  };

  const relationships = [
    {
      fromObject: 'voiceCall',
      fromField: 'contact',
      toObject: 'person',
      type: 'MANY_TO_ONE',
    },
    {
      fromObject: 'voiceCall',
      fromField: 'workflowExecution',
      toObject: 'workflowExecution',
      type: 'MANY_TO_ONE',
    },
    {
      fromObject: 'workflowExecution',
      fromField: 'workflow',
      toObject: 'workflow',
      type: 'MANY_TO_ONE',
    },
    {
      fromObject: 'workflowExecution',
      fromField: 'contact',
      toObject: 'person',
      type: 'MANY_TO_ONE',
    },
    {
      fromObject: 'communicationLog',
      fromField: 'contact',
      toObject: 'person',
      type: 'MANY_TO_ONE',
    },
    {
      fromObject: 'communicationLog',
      fromField: 'workflowExecution',
      toObject: 'workflowExecution',
      type: 'MANY_TO_ONE',
    },
  ];

  for (const rel of relationships) {
    try {
      console.log(`🔗 Creating relationship: ${rel.fromObject}.${rel.fromField} -> ${rel.toObject}`);
      
      const fromObjectId = await getObjectId(rel.fromObject);
      const toObjectId = await getObjectId(rel.toObject);
      
      if (!fromObjectId || !toObjectId) {
        console.error(`   ⚠️  Could not find object IDs for ${rel.fromObject} or ${rel.toObject}`);
        continue;
      }
      
      const mutation = `
        mutation CreateRelation($input: CreateRelationInput!) {
          createRelation(input: $input) {
            relation {
              id
            }
          }
        }
      `;

      const variables = {
        input: {
          relation: {
            fromObjectMetadataId: fromObjectId,
            toObjectMetadataId: toObjectId,
            fromFieldMetadataId: rel.fromField,
            relationType: rel.type,
          }
        }
      };

      await graphql(mutation, variables);
      console.log(`   ✅ Created relationship: ${rel.fromObject} -> ${rel.toObject}`);
    } catch (error: any) {
      if (error.message.includes('already exists') || error.message.includes('duplicate')) {
        console.log(`   ⏭️  Relationship already exists: ${rel.fromObject} -> ${rel.toObject}`);
      } else {
        console.error(`   ❌ Failed to create relationship ${rel.fromObject} -> ${rel.toObject}:`, error.message);
      }
    }
  }
}

// ==================== Step 4: Verify Migration ====================
async function verifyMigration() {
  console.log('\n✔️  Step 4: Verifying Migration...\n');
  
  try {
    const query = `query { 
      objects(paging: { first: 100 }) { 
        edges { 
          node { 
            id 
            nameSingular 
            fields {
              edges {
                node {
                  name
                  label
                }
              }
            }
          } 
        } 
      } 
    }`;
    const result = await graphql(query);
    
    const objects = result.objects.edges.map((e: any) => e.node);
    const customObjects = objects.filter((o: any) => 
      ['agentSetting', 'sallaProduct', 'sallaOrder', 'sallaCart', 'voiceCall', 'workflowExecution', 'communicationLog'].includes(o.nameSingular)
    );
    
    console.log(`✅ Found ${customObjects.length}/7 custom objects:`);
    customObjects.forEach((obj: any) => {
      const fieldCount = obj.fields?.edges?.length || 0;
      console.log(`   - ${obj.nameSingular} (${fieldCount} fields)`);
    });
    
    console.log(`\n✅ Migration verification complete`);
  } catch (error: any) {
    console.error('❌ Verification failed:', error.message);
  }
}

// Run the migration
main().catch(error => {
  console.error('\n❌ Migration failed:', error.message);
  process.exit(1);
});
