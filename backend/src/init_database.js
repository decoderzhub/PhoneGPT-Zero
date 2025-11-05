// init_database.js - Complete database initialization with your password
// Run this in your backend/src directory: node init_database.js

const Database = require('better-sqlite3');
const bcrypt = require('bcryptjs');
const path = require('path');

console.log('🚀 PhoneGPT Database Initialization');
console.log('=' . repeat(50));

// Your database is empty, so we'll create everything from scratch
const db = new Database('phonegpt.db');

console.log('📁 Database location:', path.resolve('phonegpt.db'));
console.log('\n📋 Creating tables...\n');

try {
  // Create all tables
  db.exec(`
    -- Drop existing tables if any (clean slate)
    DROP TABLE IF EXISTS documents;
    DROP TABLE IF EXISTS mentraosDevices;
    DROP TABLE IF EXISTS chatMessages;
    DROP TABLE IF EXISTS chatSessions;
    DROP TABLE IF EXISTS users;

    -- Create users table
    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL,
      name TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      last_login DATETIME
    );

    -- Create chat sessions table
    CREATE TABLE chatSessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      userId INTEGER NOT NULL,
      sessionName TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
    );

    -- Create chat messages table
    CREATE TABLE chatMessages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sessionId INTEGER NOT NULL,
      role TEXT NOT NULL,
      content TEXT NOT NULL,
      timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (sessionId) REFERENCES chatSessions(id) ON DELETE CASCADE
    );

    -- Create MentraOS devices table
    CREATE TABLE mentraosDevices (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      deviceId TEXT UNIQUE NOT NULL,
      userId INTEGER NOT NULL,
      sessionId INTEGER,
      deviceModel TEXT,
      registered_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      last_sync DATETIME,
      battery_level INTEGER,
      is_connected BOOLEAN DEFAULT 1,
      FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (sessionId) REFERENCES chatSessions(id) ON DELETE CASCADE
    );

    -- Create documents table
    CREATE TABLE documents (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      userId INTEGER NOT NULL,
      fileName TEXT NOT NULL,
      content TEXT NOT NULL,
      embedding BLOB,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
    );
  `);

  console.log('✅ All tables created successfully!\n');

  // Now create your user with the password you specified
  const email = 'darin.j.manley@gmail.com';
  const password = 'J33p$@hara85!!';  // Your specified password
  const name = 'Darin';

  console.log('👤 Creating user account...\n');

  // Hash the password
  bcrypt.hash(password, 10).then((hashedPassword) => {
    // Create user
    const userResult = db.prepare(
      'INSERT INTO users (email, password, name) VALUES (?, ?, ?)'
    ).run(email, hashedPassword, name);

    console.log(`✅ User created with ID: ${userResult.lastInsertRowid}`);

    // Create a default session for the user
    const sessionResult = db.prepare(
      'INSERT INTO chatSessions (userId, sessionName) VALUES (?, ?)'
    ).run(userResult.lastInsertRowid, 'Main Session');

    console.log(`✅ Default session created with ID: ${sessionResult.lastInsertRowid}`);

    // Add a welcome message
    db.prepare(
      'INSERT INTO chatMessages (sessionId, role, content) VALUES (?, ?, ?)'
    ).run(sessionResult.lastInsertRowid, 'assistant', 'Welcome to PhoneGPT! How can I help you today?');

    console.log('✅ Welcome message added\n');

    // Verify the password works
    const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email);
    
    bcrypt.compare(password, user.password).then((isValid) => {
      if (isValid) {
        console.log('=' . repeat(50));
        console.log('🎉 DATABASE SETUP COMPLETE!');
        console.log('=' . repeat(50));
        console.log('\n📱 You can now login with:');
        console.log(`📧 Email: ${email}`);
        console.log(`🔑 Password: ${password}`);
        console.log('=' . repeat(50));
        
        // Show database statistics
        const tables = db.prepare(`
          SELECT name FROM sqlite_master 
          WHERE type='table' 
          ORDER BY name
        `).all();
        
        console.log('\n📊 Database Statistics:');
        tables.forEach(table => {
          const count = db.prepare(`SELECT COUNT(*) as count FROM ${table.name}`).get();
          console.log(`   - ${table.name}: ${count.count} records`);
        });
        
        console.log('\n✅ Your backend is now ready to use!');
        console.log('🚀 Run "npm run dev" to start the server');
        
      } else {
        console.log('❌ Password verification failed!');
      }
      
      db.close();
    });
  }).catch(error => {
    console.error('❌ Error creating user:', error);
    db.close();
  });

} catch (error) {
  console.error('❌ Database initialization failed:', error);
  db.close();
  process.exit(1);
}