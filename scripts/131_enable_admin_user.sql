-- Enable pigwacactus@gmail.com as admin
-- Run this script after running script 130

UPDATE profiles 
SET 
  is_admin = TRUE,
  role = 'admin',
  updated_at = NOW()
WHERE email = 'pigwacactus@gmail.com';

-- Verify the update
SELECT 
  id,
  username,
  email,
  is_admin,
  role,
  disabled,
  created_at
FROM profiles 
WHERE email = 'pigwacactus@gmail.com';
