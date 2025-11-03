/*
  # Create Connected Devices Table

  1. New Tables
    - `connected_devices`
      - `id` (uuid, primary key)
      - `device_id` (text) - Unique identifier for the device
      - `name` (text) - Device display name
      - `type` (text) - Device type (even_realities, smart_home, wearable)
      - `is_connected` (boolean) - Connection status
      - `created_at` (timestamptz) - When device was added
      - `updated_at` (timestamptz) - Last connection status update

  2. Security
    - Enable RLS on `connected_devices` table
    - Devices are accessible to anyone on this device (no auth required for local app)

  3. Indexes
    - Index on device_id for quick lookups
*/

CREATE TABLE IF NOT EXISTS connected_devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id text UNIQUE NOT NULL,
  name text NOT NULL,
  type text NOT NULL CHECK (type IN ('even_realities', 'smart_home', 'wearable')),
  is_connected boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_connected_devices_device_id ON connected_devices(device_id);

ALTER TABLE connected_devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all operations on connected_devices"
  ON connected_devices
  FOR ALL
  USING (true)
  WITH CHECK (true);
