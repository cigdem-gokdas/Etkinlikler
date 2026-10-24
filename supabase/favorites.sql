-- Yalnızca referans: kullanıcı tarafından Dashboard'da zaten kurulmuş şema.
-- Bu dosya uygulama veya kurulum komutları tarafından çalıştırılmaz.
-- Canlı DDL/policy adları introspection ile doğrulanmadı.
-- Aşağıdaki DDL uygulanacak bir migration değildir; tekrar çalıştırmayın.
/*
CREATE TABLE public.favorites (
  user_id uuid NOT NULL REFERENCES auth.users(id),
  event_id text NOT NULL,
  title text NOT NULL,
  image_url text,
  starts_at timestamptz,
  location text,
  category text,
  saved_at timestamptz DEFAULT now(),
  PRIMARY KEY (user_id, event_id)
);
CREATE INDEX ON public.favorites (user_id, saved_at DESC);
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

-- Politika adları belgelenmedi; aşağıdakiler yalnızca koşulların referansıdır.
-- SELECT TO authenticated: USING (auth.uid() = user_id)
-- INSERT TO authenticated: WITH CHECK (auth.uid() = user_id)
-- DELETE TO authenticated: USING (auth.uid() = user_id)
-- Anon erişim verilmemelidir. UPDATE politikası bu aşamada kullanılmaz.
*/
