script {
   use 0x1::CoreAddresses;
   use 0x1::Account;
   use 0x1::Signer;
   use 0x1::TransactionTimeout;
   use 0x1::Timestamp;
   use 0x1::STC::{Self,STC};
   use 0x1::PackageTxnManager;
   use 0x1::Consensus;
   use 0x1::Version;
   use 0x1::VMConfig;
   use 0x1::Vector;
   use 0x1::Block;
   use 0x1::TransactionFee;
   use 0x1::BlockReward;
   use 0x1::ChainId;
   use 0x1::ConsensusStrategy;

fun genesis_init(publishing_option: vector<u8>, instruction_schedule: vector<u8>,
                 native_schedule: vector<u8>, reward_delay: u64,
                 uncle_rate_target:u64,epoch_time_target: u64,
                 reward_half_epoch: u64, init_block_time_target: u64,
                 block_difficulty_window: u64, reward_per_uncle_percent: u64,
                 min_time_target:u64, max_uncles_per_block:u64,
                 total_supply: u128, pre_mine_percent:u64, parent_hash: vector<u8>,
                 association_auth_key: vector<u8>, genesis_auth_key: vector<u8>,
                 chain_id: u8, consensus_strategy: u8, genesis_timestamp: u64,
                 block_gas_limit: u64,
                 global_memory_per_byte_cost: u64,
                 global_memory_per_byte_write_cost: u64,
                 min_transaction_gas_units: u64,
                 large_transaction_cutoff: u64,
                 instrinsic_gas_per_byte: u64,
                 maximum_number_of_gas_units: u64,
                 min_price_per_gas_unit: u64,
                 max_price_per_gas_unit: u64,
                 max_transaction_size_in_bytes: u64,
                 gas_unit_scaling_factor: u64,
                 default_account_size: u64,
                 ) {

        assert(Timestamp::is_genesis(), 1);

        let dummy_auth_key_prefix = x"00000000000000000000000000000000";

        // create genesis account
        let genesis_account = Account::create_genesis_account(CoreAddresses::GENESIS_ACCOUNT(),copy dummy_auth_key_prefix);

        //Init global time
        Timestamp::initialize(&genesis_account, genesis_timestamp);
        ChainId::initialize(&genesis_account, chain_id);
        ConsensusStrategy::initialize(&genesis_account, consensus_strategy);

        Block::initialize(&genesis_account, parent_hash);

        // init config
        VMConfig::initialize(&genesis_account, publishing_option, instruction_schedule, native_schedule,
            block_gas_limit,
            global_memory_per_byte_cost,
            global_memory_per_byte_write_cost,
            min_transaction_gas_units,
            large_transaction_cutoff,
            instrinsic_gas_per_byte,
            maximum_number_of_gas_units,
            min_price_per_gas_unit,
            max_price_per_gas_unit,
            max_transaction_size_in_bytes,
            gas_unit_scaling_factor,
            default_account_size
            );
        Version::initialize(&genesis_account);

        TransactionTimeout::initialize(&genesis_account);

        STC::initialize(&genesis_account);
        Account::accept_token<STC>(&genesis_account);

        let association = Account::create_genesis_account(CoreAddresses::ASSOCIATION_ROOT_ADDRESS(), copy dummy_auth_key_prefix);
        Account::accept_token<STC>(&association);

        let pre_mine_balance = total_supply * (pre_mine_percent as u128) / 100;
        if (pre_mine_balance > 0) {
             Account::mint_to_address<STC>(&genesis_account, Signer::address_of(&association), pre_mine_balance);
        };

        let miner_reward_balance = total_supply - pre_mine_balance;
        let init_reward_per_epoch = miner_reward_balance / (reward_half_epoch * 2 as u128);
        Consensus::initialize(&genesis_account,uncle_rate_target,epoch_time_target,reward_half_epoch, init_block_time_target, block_difficulty_window,
                                init_reward_per_epoch, reward_per_uncle_percent, min_time_target, max_uncles_per_block);

        BlockReward::initialize(&genesis_account, miner_reward_balance, reward_delay);

        TransactionFee::initialize(&genesis_account);
        //Grant stdlib maintainer to association
        PackageTxnManager::grant_maintainer(&genesis_account, Signer::address_of(&association));
        //TODO set stdlib upgrade strategy.

        // only dev network set genesis auth key.
        if (!Vector::is_empty(&genesis_auth_key)){
            let genesis_rotate_key_cap = Account::extract_key_rotation_capability(&genesis_account);
            Account::rotate_authentication_key(&genesis_rotate_key_cap, genesis_auth_key);
            Account::restore_key_rotation_capability(genesis_rotate_key_cap);
        };

        let assoc_rotate_key_cap = Account::extract_key_rotation_capability(&association);
        Account::rotate_authentication_key(&assoc_rotate_key_cap, association_auth_key);
        Account::restore_key_rotation_capability(assoc_rotate_key_cap);

        //Start time, Timestamp::is_genesis() will return false. this call should at the end of genesis init.
        Timestamp::set_time_has_started(&genesis_account);
        Account::release_genesis_signer(genesis_account);
        Account::release_genesis_signer(association);

}
}