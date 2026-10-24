import { randomUUID } from 'node:crypto';
import { openDatabase, now, audit, consentVersion } from './db.mjs';
import { hashPassword } from './auth.mjs';

const db = openDatabase();
if (db.prepare('SELECT COUNT(*) AS n FROM users').get().n) {
  console.log('Database already contains accounts; demo seed skipped.'); db.close();
} else {
  const hash = await hashPassword('VoiceDemo!2026');
  const timestamp = days => new Date(Date.now() - days * 86400000).toISOString();
  const add = (name,email,role,status='active',therapist=null,days=30) => {
    const id=randomUUID(); db.prepare('INSERT INTO users VALUES (?,?,?,?,?,?,?,?,?,?)').run(id,name,email,hash,role,status,role==='therapist'?'Voice & Speech Clinic':'',role==='therapist'?`SLP-${Math.floor(10000+Math.random()*90000)}`:'',therapist,timestamp(days)); return id;
  };
  db.exec('BEGIN');
  try {
    const admin=add('Alex Morgan','admin@melo.test','admin');
    const therapists=[add('Dr. Meera Kapoor','meera@melo.test','therapist'),add('Dr. Arjun Singh','arjun@melo.test','therapist'),add('Dr. Sara Thomas','sara@melo.test','therapist')];
    add('Dr. Riya Sharma','riya@melo.test','therapist','pending',null,1);
    add('Dr. Kabir Mehta','kabir@melo.test','therapist','pending',null,0.3);
    const names=['Ananya Rao','Rohan Malhotra','Priya Nair','Ishaan Gupta','Simran Kaur','Dev Patel','Aisha Khan','Vikram Joshi','Neha Verma','Aarav Shah','Kavya Iyer','Aditya Bose','Tara Menon','Rahul Sethi','Sana Ali','Nikhil Rao','Maya Das','Ankit Jain'];
    for(let i=0;i<names.length;i++) {
      const therapist=i>15?null:therapists[i%3]; const patient=add(names[i],i===0?'patient@melo.test':`${names[i].toLowerCase().replaceAll(' ','.')}@melo.test`,'patient','active',therapist,25-i);
      if(i>14) continue;
      const consent=randomUUID();
      const png='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6o1sAAAAASUVORK5CYII=';
      db.prepare('INSERT INTO consents VALUES (?,?,?,?,?,?,?,?,?,?,?)').run(consent,patient,consentVersion,i===0?'Synthetic parent or legal guardian':names[i],png,JSON.stringify({adult:true,participation:true,dataSharing:true,analysis:i%2===0}),i>12?'pending':'approved',timestamp(24-i),i>12?null:therapist,i>12?null:timestamp(23-i),i>12?0:1);
      if(i>12) continue;
      db.prepare('INSERT INTO clinical_forms VALUES (?,?,?,?,?,?)').run(patient,i===0?7:25+i,'Synthetic demographic record','Synthetic clinical assessment for dashboard demonstration',therapist,timestamp(23-i));
      const plan=randomUUID();
      db.prepare('INSERT INTO plans VALUES (?,?,?,?,?,?,?,?,?)').run(plan,patient,therapist,consent,i===0?'My daily little practice':'Your daily voice practice',JSON.stringify(i===0?['motor-lines','motor-shapes','motor-letter']:['humming','breathing','reading']),i===0?1:2,i===0?'Take your time. Rest whenever your hand feels tired. Ask a grown-up to help photograph just the paper.':'Practice at a comfortable volume. Follow the technique discussed in your appointment.',timestamp(22-i));
      for(let d=13;d>=0;d--) {
        if(i===0) continue;
        if((d+i)%5===0 || (i===4 && d<5)) continue;
        for(let s=0;s<1+(i+d)%2;s++) db.prepare('INSERT INTO progress VALUES (?,?,?,?,?,?,?)').run(randomUUID(),patient,plan,['humming','breathing','reading'][(i+d+s)%3],5+(i%4),timestamp(d+s/24),timestamp(d+s/24));
      }
      if(i<4) audit(db,therapist,'Prescribed plan',patient,names[i]);
    }
    audit(db,admin,'Demo workspace created',null,'Synthetic records for local development');
    db.prepare('INSERT INTO settings VALUES (?,?)').run('demo','true');
    db.exec('COMMIT');
    console.log('Synthetic demo workspace created. Admin: admin@melo.test | Password: VoiceDemo!2026');
  } catch(e) {db.exec('ROLLBACK');throw e;} finally {db.close();}
}
