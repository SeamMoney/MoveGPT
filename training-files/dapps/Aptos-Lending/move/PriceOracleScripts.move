address Quantum {
module PriceOracleScripts{
    use Quantum::PriceOracle;

    public entry fun register_oracle<OracleT: copy+store+drop>(sender: signer, precision: u8){
        PriceOracle::register_oracle<OracleT>(&sender, precision)
    }

    public entry fun init_data_source<OracleT: copy+store+drop>(sender: signer, init_value: u64){
        PriceOracle::init_data_source<OracleT>(&sender, init_value);
    }

    public entry fun update<OracleT: copy+store+drop>(sender: signer, value: u64){
        PriceOracle::update<OracleT>(&sender, value);
    }
}
}