use snforge_std::EventSpyAssertionsTrait;
// import library
use snforge_std::{
    declare, DeclareResultTrait, ContractClassTrait, spy_events, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::{ContractAddress};
use contracts::counter::{
    ICounterDispatcher, ICounterDispatcherTrait, Counter, ICounterSafeDispatcher,
    ICounterSafeDispatcherTrait,
};
use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};

const ZERO_COUNT: u32 = 0;

// test account
fn OWNER() -> ContractAddress {
    // return the address of the owner
    // 'OWNER'.try_into().expect('')
    'OWNER'.try_into().unwrap()
}

fn USER_1() -> ContractAddress {
    // return the address of the user_1
    'USER_1'.try_into().unwrap()
}

// util deploy function
fn __deploy__(init_value: u32) -> (ICounterDispatcher, IOwnableDispatcher, ICounterSafeDispatcher) {
    // declare the contract
    let contract_class = declare("Counter").unwrap().contract_class();
    // let contract_class = declare("Counter").expect('failed to declare').contract_class();

    //serialize constructor
    let mut calldata: Array<felt252> = array![];
    ZERO_COUNT.serialize(ref calldata);
    OWNER().serialize(ref calldata);

    //deploy the contract
    let (contract_address, _) = contract_class.deploy(@calldata).expect('failed to deploy');

    let counter = ICounterDispatcher { contract_address: contract_address };
    let ownable = IOwnableDispatcher { contract_address };
    let safe_dispatcher = ICounterSafeDispatcher { contract_address };
    (counter, ownable, safe_dispatcher)
}

#[test]
fn test_counter_deployment() {
    // deploy the contract
    let (counter, ownable, _) = __deploy__(ZERO_COUNT);
    // count 1
    let count_1 = counter.get_counter();

    //assertions
    assert(count_1 == ZERO_COUNT, 'count not set');
    assert(ownable.owner() == OWNER(), 'owner not set');
}


#[test]
fn test_increase_counter() {
    let (counter, _, _) = __deploy__(ZERO_COUNT);
    //get current count
    let count_1 = counter.get_counter();

    //assertions
    assert(count_1 == ZERO_COUNT, 'count not set');

    //state-changing txn
    counter.increase_counter();

    //retrieve current count
    let count_2 = counter.get_counter();

    //assert that count increase by 1
    assert(count_2 == count_1 + 1, 'invalid count')
}

#[test]
fn test_emited_increased_event() {
    let (counter, _, _) = __deploy__(ZERO_COUNT);
    let mut spy = spy_events();
    start_cheat_caller_address(counter.contract_address, USER_1());

    counter.increase_counter();
    stop_cheat_caller_address(counter.contract_address);
    spy
        .assert_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Increased(Counter::Increased { account: USER_1() }),
                ),
            ],
        );

    spy
        .assert_not_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Increased(Counter::Increased { account: USER_1() }),
                ),
            ],
        )
}

#[test]
#[feature("safe_dispatcher")]
fn test_safe_Panic_decrease_counter() {
    let (counter, _, safe_dispatcher) = __deploy__(ZERO_COUNT);

    assert(counter.get_counter() == ZERO_COUNT, 'invalid count');

    match safe_dispatcher.decrease_counter() {
        Result::Ok(_) => panic!("cannot decrease 0"),
        Result::Err(e) => assert(*e[0] == 'Decreasing Empty Counter', *e.at(0)),
    }
}

#[test]
#[should_panic(expected: 'Decreasing Empty Counter')]
fn test_panic_decrease_counter() {
    let (counter, _, _) = __deploy__(ZERO_COUNT);

    assert(counter.get_counter() == ZERO_COUNT, 'invalid count');

    counter.decrease_counter();
}

#[test]
fn test_successful_decrease_counter() {
    let (counter, _, _) = __deploy__(5);
    let count_1 = counter.get_counter();

    assert(count_1 == 5, 'invalid count');

    // execute  decrease_counter txn
    counter.decrease_counter();

    let final_count = counter.get_counter();
    assert(final_count == count_1 - 1, 'invalid  decrease count');
}


#[test]
#[feature("safe_dispatcher")]
fn test_safe_Panic_reset_counter_by_non_owner() {
    let (counter, _, safe_dispatcher) = __deploy__(ZERO_COUNT);

    assert(counter.get_counter() == ZERO_COUNT, 'invalid count');

    start_cheat_caller_address(counter.contract_address, USER_1());

    match safe_dispatcher.reset_counter() {
        Result::Ok(_) => panic!("cannot reset"),
        Result::Err(e) => assert(*e[0] == 'Caller is not the owner', *e.at(0)),
    }
}


#[test]
fn test_successful_reset_counter() {
    let (counter, _, _) = __deploy__(5);
    let count_1 = counter.get_counter();

    assert(count_1 == 5, 'invalid count');

    start_cheat_caller_address(counter.contract_address, OWNER());
    counter.reset_counter();
    stop_cheat_caller_address(counter.contract_address);

    assert(counter.get_counter() == 0, 'not reset to 0');
}
