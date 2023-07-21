module oracle::oracle{
   use std::signer;

   const ERROR_ALREADY_INITIALIZED:u64 = 1;
   const ERROR_ORACLE_DATA:u64 = 2;

   struct OracleData<X> has key {
      value: X
   }

   public entry fun init_oracle(admin: &signer, data: u64){
      let admin_addr = signer::address_of(admin);
      assert!(exists<OracleData<u64>>(admin_addr),ERROR_ALREADY_INITIALIZED);
      move_to<OracleData<u64>>(admin, OracleData{
         value: data
      });
   }

   public entry fun update_data(admin: &signer, data: u64) acquires OracleData{
      let admin_addr = signer::address_of(admin);
      assert!(exists<OracleData<u64>>(admin_addr),ERROR_ORACLE_DATA);
      let oracle_data = borrow_global_mut<OracleData<u64>>(admin_addr);
      oracle_data.value = data;
   }
}
