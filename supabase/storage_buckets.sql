-- Create Storage Buckets

-- Create claim-photos bucket
INSERT INTO storage.buckets (id, name, public, avif_autodetection, allowed_mime_types, file_size_limit)
VALUES (
  'claim-photos',
  'claim-photos',
  false,
  false,
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/heif', 'image/heic'],
  52428800 -- 50MB limit
);

-- Create documents bucket
INSERT INTO storage.buckets (id, name, public, avif_autodetection, allowed_mime_types, file_size_limit)
VALUES (
  'documents',
  'documents',
  false,
  false,
  ARRAY['application/pdf', 'image/jpeg', 'image/jpg', 'image/png'],
  104857600 -- 100MB limit
);

-- Storage policies for claim-photos bucket
CREATE POLICY "Users can view own claim photos" ON storage.objects
  FOR SELECT USING (
    auth.uid()::text = (storage.foldername(name))[1] AND 
    bucket_id = 'claim-photos'
  );

CREATE POLICY "Users can upload claim photos" ON storage.objects
  FOR INSERT WITH CHECK (
    auth.uid()::text = (storage.foldername(name))[1] AND 
    bucket_id = 'claim-photos'
  );

CREATE POLICY "Users can update own claim photos" ON storage.objects
  FOR UPDATE USING (
    auth.uid()::text = (storage.foldername(name))[1] AND 
    bucket_id = 'claim-photos'
  );

CREATE POLICY "Users can delete own claim photos" ON storage.objects
  FOR DELETE USING (
    auth.uid()::text = (storage.foldername(name))[1] AND 
    bucket_id = 'claim-photos'
  );

-- Storage policies for documents bucket
CREATE POLICY "Users can view own documents" ON storage.objects
  FOR SELECT USING (
    auth.uid()::text = (storage.foldername(name))[1] AND 
    bucket_id = 'documents'
  );

CREATE POLICY "Users can upload documents" ON storage.objects
  FOR INSERT WITH CHECK (
    auth.uid()::text = (storage.foldername(name))[1] AND 
    bucket_id = 'documents'
  );

CREATE POLICY "Users can update own documents" ON storage.objects
  FOR UPDATE USING (
    auth.uid()::text = (storage.foldername(name))[1] AND 
    bucket_id = 'documents'
  );

CREATE POLICY "Users can delete own documents" ON storage.objects
  FOR DELETE USING (
    auth.uid()::text = (storage.foldername(name))[1] AND 
    bucket_id = 'documents'
  );
