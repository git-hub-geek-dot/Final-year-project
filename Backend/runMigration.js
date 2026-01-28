require('dotenv').config();
const pool = require('./config/db');
const fs = require('fs');
const path = require('path');

async function runMigration() {
  try {
    console.log('Starting migration...');
    console.log('Checking if profile_picture_url column exists...');
    
    // Check if column exists
    const checkColumnQuery = `
      SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'profile_picture_url'
      );
    `;
    
    const result = await pool.query(checkColumnQuery);
    const columnExists = result.rows[0].exists;
    
    if (columnExists) {
      console.log('✅ Column profile_picture_url already exists!');
    } else {
      console.log('Adding profile_picture_url column...');
      
      const addColumnQuery = `
        ALTER TABLE users ADD COLUMN profile_picture_url VARCHAR(500);
      `;
      
      await pool.query(addColumnQuery);
      console.log('✅ Column profile_picture_url added successfully!');
    }
    
    // Verify the column
    const verifyQuery = `
      SELECT column_name, data_type FROM information_schema.columns 
      WHERE table_name = 'users' AND column_name = 'profile_picture_url';
    `;
    
    const verifyResult = await pool.query(verifyQuery);
    if (verifyResult.rows.length > 0) {
      console.log('✅ Verification passed:');
      console.log(`   Column: ${verifyResult.rows[0].column_name}`);
      console.log(`   Type: ${verifyResult.rows[0].data_type}`);
    }
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error.message);
    process.exit(1);
  }
}

runMigration();
