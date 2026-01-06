CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  role VARCHAR(20) CHECK (role IN ('organiser','volunteer','admin')),
  created_at TIMESTAMP DEFAULT now()
);

CREATE TABLE events (
  id SERIAL PRIMARY KEY,
  organizer_id INTEGER REFERENCES users(id),
  title TEXT NOT NULL,
  description TEXT,
  location TEXT,
  event_date DATE,
  status VARCHAR(20) DEFAULT 'open'
);

CREATE TABLE applications (
  id SERIAL PRIMARY KEY,
  event_id INTEGER REFERENCES events(id),
  volunteer_id INTEGER REFERENCES users(id),
  status VARCHAR(20) DEFAULT 'pending',
  applied_at TIMESTAMP DEFAULT now()
);
