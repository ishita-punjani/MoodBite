-- Mumbai delivery zones (approximate area centres, WGS84).
-- Same rows as data/zones.csv; scripts/check_data.py verifies they match.
-- A delivery point is accepted if it is within app_config.zone_radius_km of any centre.

insert into public.zones (id, name, lat, lng) values
  ('z01', 'Colaba',       18.9067, 72.8147),
  ('z02', 'Fort',         18.9322, 72.8347),
  ('z03', 'Churchgate',   18.9322, 72.8264),
  ('z04', 'Girgaon',      18.9550, 72.8170),
  ('z05', 'Tardeo',       18.9701, 72.8137),
  ('z06', 'Byculla',      18.9790, 72.8330),
  ('z07', 'Lower Parel',  18.9953, 72.8300),
  ('z08', 'Worli',        19.0176, 72.8162),
  ('z09', 'Dadar',        19.0178, 72.8478),
  ('z10', 'Matunga',      19.0275, 72.8550),
  ('z11', 'Mahim',        19.0410, 72.8410),
  ('z12', 'Sion',         19.0390, 72.8619),
  ('z13', 'Bandra West',  19.0596, 72.8295),
  ('z14', 'Bandra East',  19.0600, 72.8500),
  ('z15', 'Khar',         19.0700, 72.8370),
  ('z16', 'Santacruz',    19.0810, 72.8420),
  ('z17', 'Vile Parle',   19.0990, 72.8440),
  ('z18', 'Juhu',         19.1075, 72.8263),
  ('z19', 'Andheri West', 19.1364, 72.8296),
  ('z20', 'Andheri East', 19.1136, 72.8697),
  ('z21', 'Powai',        19.1176, 72.9060),
  ('z22', 'Ghatkopar',    19.0860, 72.9081),
  ('z23', 'Chembur',      19.0522, 72.9005),
  ('z24', 'Goregaon',     19.1663, 72.8526),
  ('z25', 'Malad',        19.1874, 72.8484),
  ('z26', 'Borivali',     19.2307, 72.8567),
  ('z27', 'Mulund',       19.1726, 72.9565);
