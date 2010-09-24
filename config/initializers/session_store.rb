# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_recipe_scraper_session',
  :secret      => 'e0fb89e91ae2c067a2063e6eaad344adf00c80efa3d116a93c27a8d18a235f95dca8bd2439507d0930c3439adcebed6d0d96821f0570ab0701e878684fa251bc'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
