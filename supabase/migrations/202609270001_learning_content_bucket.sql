INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
) VALUES (
  'learning-content',
  'learning-content',
  true,
  1048576,
  ARRAY['application/json', 'application/gzip']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Public buckets allow read access through Storage's public object endpoint.
-- No INSERT, UPDATE or DELETE policy is granted to anon/authenticated users;
-- publication is performed only with the server-side service role.
