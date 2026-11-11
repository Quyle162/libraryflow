import 'dotenv/config';
import mysql from 'mysql2/promise';

export const pool = mysql.createPool({
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'libraryflow_db',
  charset: 'utf8mb4',
  timezone: 'Z',
  connectionLimit: 10,
});

pool.on('connection', connection => {
  connection.query("SET time_zone = '+00:00'");
});

export async function query(connection, sql, values = []) {
  const [result] = await connection.execute(sql, values);
  return result;
}

export async function one(connection, sql, values = []) {
  return (await query(connection, sql, values))[0];
}

export async function transaction(work) {
  const connection = await pool.getConnection();
  try {
    await connection.query('SET TRANSACTION ISOLATION LEVEL READ COMMITTED');
    await connection.beginTransaction();
    const result = await work(connection);
    await connection.commit();
    return result;
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}
