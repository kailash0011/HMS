const express = require("express");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const { getPool, sql } = require("../db");

const router = express.Router();

router.post("/register", async (req, res) => {
  try {
    const { username, password, full_name, phone, email } = req.body;
    if (!username || !password || !full_name) {
      return res.status(400).json({ error: "username, password, and full_name are required" });
    }

    const pool = await getPool();
    const existing = await pool
      .request()
      .input("username", sql.NVarChar(100), username)
      .query("SELECT user_id FROM sec_users WHERE username = @username");

    if (existing.recordset.length > 0) {
      return res.status(409).json({ error: "Username already exists" });
    }

    const password_hash = await bcrypt.hash(password, 10);

    const insert = await pool
      .request()
      .input("username", sql.NVarChar(100), username)
      .input("password_hash", sql.NVarChar(255), password_hash)
      .input("full_name", sql.NVarChar(150), full_name)
      .input("phone", sql.NVarChar(20), phone || null)
      .input("email", sql.NVarChar(150), email || null)
      .query("INSERT INTO sec_users (username, password_hash, full_name, phone, email) OUTPUT INSERTED.user_id VALUES (@username, @password_hash, @full_name, @phone, @email)");

    return res.status(201).json({ user_id: insert.recordset[0].user_id });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

router.post("/login", async (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) {
      return res.status(400).json({ error: "username and password are required" });
    }

    const pool = await getPool();
    const result = await pool
      .request()
      .input("username", sql.NVarChar(100), username)
      .query("SELECT user_id, username, full_name, password_hash FROM sec_users WHERE username = @username AND is_active = 1");

    if (result.recordset.length === 0) {
      return res.status(401).json({ error: "Invalid credentials" });
    }

    const user = result.recordset[0];
    const match = await bcrypt.compare(password, user.password_hash);
    if (!match) {
      return res.status(401).json({ error: "Invalid credentials" });
    }

    const token = jwt.sign(
      { user_id: user.user_id, username: user.username, full_name: user.full_name },
      process.env.JWT_SECRET,
      { expiresIn: "8h" }
    );

    return res.json({ token });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

module.exports = router;