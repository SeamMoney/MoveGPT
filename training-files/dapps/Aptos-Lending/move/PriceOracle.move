address Quantum {

module PriceOracle {
    use Quantum::MathU64;
    use Quantum::Oracle::{Self, DataRecord, UpdateCapability};

    struct PriceOracleInfo has copy,store,drop{
        scaling_factor: u64,
    }

    public fun register_oracle<OracleT: copy+store+drop>(sender: &signer, precision: u8){
        let scaling_factor = MathU64::exp(10, (precision as u64));
        Oracle::register_oracle<OracleT, PriceOracleInfo>(sender, PriceOracleInfo{
            scaling_factor,
        });
    }

    public fun init_data_source<OracleT: copy+store+drop>(sender: &signer, init_value: u64){
        Oracle::init_data_source<OracleT, PriceOracleInfo, u64>(sender, init_value);
    }

    public fun is_data_source_initialized<OracleT:  copy+store+drop>(ds_addr: address): bool{
        Oracle::is_data_source_initialized<OracleT, u64>(ds_addr)
    }

    public fun get_scaling_factor<OracleT: copy + store + drop>() : u64 {
        let info = Oracle::get_oracle_info<OracleT, PriceOracleInfo>();
        info.scaling_factor
    }

    public fun update<OracleT: copy+store+drop>(sender: &signer, value: u64){
        Oracle::update<OracleT, u64>(sender, value);
    }

    public fun update_with_cap<OracleT: copy+store+drop>(cap: &mut UpdateCapability<OracleT>, value: u64) {
        Oracle::update_with_cap<OracleT, u64>(cap, value);
    }

    public fun read<OracleT: copy+store+drop>(addr: address) : u64{
        Oracle::read<OracleT, u64>(addr)
    }

    public fun read_record<OracleT:copy+store+drop>(addr: address): DataRecord<u64>{
        Oracle::read_record<OracleT, u64>(addr)
    }

    public fun read_records<OracleT:copy+store+drop>(addrs: &vector<address>): vector<DataRecord<u64>>{
        Oracle::read_records<OracleT, u64>(addrs)
    }
}
}