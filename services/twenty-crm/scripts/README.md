# Twenty CRM Schema Migration

This script creates the complete data model for the Salla-Twenty CRM integration, including:

- 7 Custom Objects (Agent Settings, Salla Products, Orders, Carts, Voice Calls, Workflow Executions, Communication Logs)
- 3 Extended Objects (Person, Opportunity, Workflow)
- 6 Relationships between objects

## Setup Instructions

### 1. Set Environment Variables

```bash
export TWENTY_API_KEY="your-api-key"
export TWENTY_BASE_URL="http://138.197.23.213"
```

Or create a `.env` file:
```bash
TWENTY_API_KEY=your-api-key
TWENTY_BASE_URL=http://138.197.23.213
```

### 2. Install Dependencies

```bash
cd services/twenty-crm/scripts
npm install
```

### 3. Run Migration

```bash
npm run migrate
```

Or directly:
```bash
npx ts-node migrate-schema.ts
```

### 4. Verify Migration

The script automatically verifies all created objects and fields at the end.

## What Gets Created

### Custom Objects

1. **Agent Settings** - ElevenLabs agent configuration
2. **Salla Products** - Product data from Salla
3. **Salla Orders** - Order data from Salla
4. **Salla Carts** - Abandoned cart tracking
5. **Voice Calls** - AI voice call records
6. **Workflow Executions** - Workflow execution tracking
7. **Communication Logs** - All communication records

### Extended Objects

1. **Person** - Extended with Salla customer fields
2. **Opportunity** - Extended with Salla order fields
3. **Workflow** - Extended with workflow automation fields

### Relationships

- Voice Calls → Person
- Voice Calls → Workflow Execution
- Workflow Execution → Workflow
- Workflow Execution → Person
- Communication Log → Person
- Communication Log → Workflow Execution

## Troubleshooting

### Connection Error
- Verify `TWENTY_BASE_URL` is correct
- Check that Twenty CRM is running
- Verify API key is valid

### Already Exists Errors
- Objects/fields that already exist are skipped automatically
- This is normal if running the script multiple times

### GraphQL Errors
- Check the error message for specific field/object issues
- Verify Twenty CRM API version compatibility

## Next Steps

After migration:
1. Review the verification report
2. Test the 10 workflow automations
3. Configure workflow templates
4. Set up webhook handlers

