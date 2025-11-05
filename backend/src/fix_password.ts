// ============================================================================
// Fix Existing User Password
// Run this script once to add a password to your existing user
// ============================================================================

import Database from 'better-sqlite3';
import bcrypt from 'bcryptjs';
import dotenv from 'dotenv';

dotenv.config();

const db = new Database('phonegpt.db');

async function fixUserPassword() {
  const email = 'darin.j.manley@gmail.com';
  
  // CHANGE THIS PASSWORD!
  const newPassword = 'J33p$@hara85!!';
  
  try {
    // Check if user exists
    const user: any = db.prepare('SELECT * FROM users WHERE email = ?').get(email);
    
    if (!user) {
      console.log('❌ User not found. Creating new user...');
      
      const hashedPassword = await bcrypt.hash(newPassword, 10);
      
      const result = db.prepare(
        'INSERT INTO users (email, password, name) VALUES (?, ?, ?)'
      ).run(email, hashedPassword, 'Darin');
      
      console.log(`✅ User created with ID: ${result.lastInsertRowid}`);
      console.log(`📧 Email: ${email}`);
      console.log(`🔑 Password has been set`);
      
    } else if (!user.password) {
      console.log('✅ User found but no password set. Adding password...');
      
      const hashedPassword = await bcrypt.hash(newPassword, 10);
      
      db.prepare('UPDATE users SET password = ? WHERE email = ?')
        .run(hashedPassword, email);
      
      console.log(`✅ Password updated for user ID: ${user.id}`);
      console.log(`📧 Email: ${email}`);
      console.log(`🔑 Password has been set`);
      
    } else {
      console.log('✅ User already has a password set');
      console.log(`📧 Email: ${email}`);
      console.log('ℹ️  To reset password, uncomment the force update section below');
      
      // Uncomment to force update password even if one exists:
      /*
      const hashedPassword = await bcrypt.hash(newPassword, 10);
      db.prepare('UPDATE users SET password = ? WHERE email = ?')
        .run(hashedPassword, email);
      console.log('🔑 Password has been reset');
      */
    }
    
    // Verify the password works
    const updatedUser: any = db.prepare('SELECT * FROM users WHERE email = ?').get(email);
    const isValid = await bcrypt.compare(newPassword, updatedUser.password);
    
    if (isValid) {
      console.log('✅ Password verification successful! You can now login.');
    } else {
      console.log('❌ Password verification failed. Something went wrong.');
    }
    
  } catch (error) {
    console.error('Error:', error);
  } finally {
    db.close();
  }
}

// Run the fix
fixUserPassword();
