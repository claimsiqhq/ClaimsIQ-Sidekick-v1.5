-- Row Level Security Policies

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_timeline ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspection_checklist ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_queue ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Claims policies
CREATE POLICY "Users can view own claims" ON claims
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create claims" ON claims
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own claims" ON claims
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own claims" ON claims
  FOR DELETE USING (auth.uid() = user_id);

-- Inspections policies
CREATE POLICY "Users can view own inspections" ON inspections
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create inspections" ON inspections
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own inspections" ON inspections
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own inspections" ON inspections
  FOR DELETE USING (auth.uid() = user_id);

-- Photos policies
CREATE POLICY "Users can view own photos" ON photos
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can upload photos" ON photos
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own photos" ON photos
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own photos" ON photos
  FOR DELETE USING (auth.uid() = user_id);

-- Documents policies
CREATE POLICY "Users can view own documents" ON documents
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can upload documents" ON documents
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own documents" ON documents
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own documents" ON documents
  FOR DELETE USING (auth.uid() = user_id);

-- Activity timeline policies
CREATE POLICY "Users can view own activities" ON activity_timeline
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create activities" ON activity_timeline
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Inspection checklist policies
CREATE POLICY "Users can view own checklist items" ON inspection_checklist
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create checklist items" ON inspection_checklist
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own checklist items" ON inspection_checklist
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own checklist items" ON inspection_checklist
  FOR DELETE USING (auth.uid() = user_id);

-- Sync queue policies
CREATE POLICY "Users can view own sync queue" ON sync_queue
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create sync queue items" ON sync_queue
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own sync queue items" ON sync_queue
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own sync queue items" ON sync_queue
  FOR DELETE USING (auth.uid() = user_id);

-- Function to automatically create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name)
  VALUES (new.id, new.raw_user_meta_data->>'full_name');
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for new user profile creation
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
