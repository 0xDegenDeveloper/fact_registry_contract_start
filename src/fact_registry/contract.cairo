#[starknet::interface]
pub trait IFactRegistry<TContractState> {
    fn get_fact(self: @TContractState, job_id: felt252) -> Span<felt252>;
    fn set_fact(
        ref self: TContractState, job_request: FactRegistry::JobRequest, job_data: Span<felt252>
    ) -> felt252;
}

#[starknet::contract]
pub mod FactRegistry {
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess,};
    use starknet::storage::{Map, StoragePathEntry};
    use core::poseidon::poseidon_hash_span;
    use super::IFactRegistry;

    const FACT_SIZE: usize = 5; // (u256, u128, u256)

    #[derive(Copy, Destruct, Serde)]
    pub struct JobRequest {
        pub identifiers: Span<felt252>,
        pub params: JobRequestParams,
    }

    #[derive(Drop, Copy, Serde)]
    pub struct JobRequestParams {
        pub twap: (u64, u64),
        pub volatility: (u64, u64),
        pub reserve_price: (u64, u64),
    }

    #[storage]
    struct Storage {
        facts: Map<felt252, Map<usize, felt252>>,
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn make_job_id(self: @ContractState, job_request: JobRequest) -> felt252 {
            let mut identifiers: Array<felt252> = job_request.identifiers.into();

            let (p1_0, p1_1) = job_request.params.twap;
            let (p2_0, p2_1) = job_request.params.volatility;
            let (p3_0, p3_1) = job_request.params.reserve_price;

            let params: Array<felt252> = array![
                p1_0.into(), p1_1.into(), p2_0.into(), p2_1.into(), p3_0.into(), p3_1.into()
            ];

            identifiers.append_span(params.span());

            poseidon_hash_span(identifiers.span())
        }
    }

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[abi(embed_v0)]
    impl FactRegistryImpl of IFactRegistry<ContractState> {
        fn get_fact(self: @ContractState, job_id: felt252) -> Span<felt252> {
            let mut fact: Array<felt252> = array![];

            for i in 0..FACT_SIZE {
                fact.append(self.facts.entry(job_id).entry(i).read());
            };

            fact.span()
        }

        fn set_fact(
            ref self: ContractState, job_request: JobRequest, job_data: Span<felt252>
        ) -> felt252 {
            /// Proving would happen first ... ///

            let job_id = self.make_job_id(job_request);

            for i in 0..FACT_SIZE {
                self.facts.entry(job_id).entry(i).write(*job_data.at(i));
            };

            job_id
        }
    }
}
