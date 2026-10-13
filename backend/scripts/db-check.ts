import { checkDatabaseConnection } from '../src/services/dbCheck.js';

async function main() {
  console.log('Checking database connection...');
  const isConnected = await checkDatabaseConnection();
  if (isConnected) {
    console.log('✓ Database connection OK');
    process.exit(0);
  } else {
    console.log('✗ Database connection FAILED');
    process.exit(1);
  }
}

main().catch((error) => {
  console.error('Unexpected error:', error);
  process.exit(1);
});