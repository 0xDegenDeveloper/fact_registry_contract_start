use starknet::ContractAddress;
use starknet::syscalls::deploy_syscall;
use FactRegistry::{DEFAULT_RANGE, PITCH_LAKE_V1};
use FactRegistry::{JobRequest, JobRequestParams};
use fossil::fact_registry::contract::{
    FactRegistry, IFactRegistryDispatcher, IFactRegistryDispatcherTrait
};

/// Helpers ///

fn deploy_contract() -> IFactRegistryDispatcher {
    let (contract_address, _): (ContractAddress, Span<felt252>) = deploy_syscall(
        FactRegistry::TEST_CLASS_HASH.try_into().unwrap(), 0, [].span(), false
    )
        .unwrap();

    return IFactRegistryDispatcher { contract_address };
}

fn resolve_data(data: Span<felt252>) -> (u256, u128, u256) {
    let twap: u256 = u256 {
        low: (*data.at(0)).try_into().unwrap(), high: (*data.at(1)).try_into().unwrap(),
    };
    let volatility: u128 = (*data.at(2)).try_into().unwrap();
    let reserve_price: u256 = u256 {
        low: (*data.at(3)).try_into().unwrap(), high: (*data.at(4)).try_into().unwrap(),
    };

    (twap, volatility, reserve_price)
}

fn get_mock_request() -> JobRequest {
    JobRequest {
        identifiers: array![PITCH_LAKE_V1].span(),
        params: JobRequestParams {
            twap: DEFAULT_RANGE, volatility: DEFAULT_RANGE, reserve_price: DEFAULT_RANGE,
        },
    }
}

/// Tests ///

#[test]
#[available_gas(12_500_000)]
fn basic_test() {
    let fossil = deploy_contract();

    let mock_request = get_mock_request();
    let mock_data = array![1, 0, 2, 3, 0].span(); // (1_u256, 2_u128, 3_u256)

    let job_id = fossil.set_fact(mock_request, mock_data);
    let job_data = fossil.get_fact(job_id);

    let (twap, volatility, reserve_price) = resolve_data(job_data);

    //    println!("job_id: {:?}", job_id);
    //    println!("job_data: {:?}", job_data);
    //    println!(
    //        "(twap, volatility, reserve_price): ({:?}, {:?}, {:?})", twap, volatility,
    //        reserve_price
    //    );

    assert_eq!(mock_data, job_data);
    assert_eq!((1_u256, 2_u128, 3_u256), (twap, volatility, reserve_price));
}

