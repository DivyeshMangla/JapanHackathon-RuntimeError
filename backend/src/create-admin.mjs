import { randomUUID } from 'node:crypto';
import { openDatabase, now } from './db.mjs';
import { hashPassword } from './auth.mjs';
const { ADMIN_EMAIL:email, ADMIN_PASSWORD:password, ADMIN_NAME:name='Administrator' }=process.env;
if(!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || !password || password.length<12 || password.length>128 || password!==password.trim()) throw Error('Set ADMIN_EMAIL, ADMIN_NAME and ADMIN_PASSWORD (12–128 characters) in the environment.');
const db=openDatabase();
try {db.prepare('INSERT INTO users(id,name,email,password_hash,role,status,created_at) VALUES (?,?,?,?,?,?,?)').run(randomUUID(),name,email.toLowerCase(),await hashPassword(password),'admin','active',now()); console.log('Administrator created.');} finally {db.close();}
