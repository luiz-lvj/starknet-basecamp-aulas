use starknet::{ContractAddress, contract_address_const};

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address};

use aula2::IHelloWorldDispatcher;
use aula2::IHelloWorldDispatcherTrait;


fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let calldata: Array<felt252> = array![OWNER().into(), ERC20_ADDR().into()];

    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

pub fn ERC20_ADDR() -> ContractAddress {
    contract_address_const::<0x049D36570D4e46f48e99674bd3fcc84644DdD6b96F7C741B1562B82f9e004dC7>()
}

pub fn USER() -> ContractAddress {
    contract_address_const::<'USER'>()
}

pub fn OWNER() -> ContractAddress {
    contract_address_const::<'OWNER'>()
}

#[test]
fn test_register_user() {
    let contract_address = deploy_contract("HelloWorld");

    let dispatcher = IHelloWorldDispatcher { contract_address };

    let id: felt252 = 'abc';

    start_cheat_caller_address(dispatcher.contract_address, USER());
    dispatcher.register_user(id);
    stop_cheat_caller_address(dispatcher.contract_address);

    let user_registered = dispatcher.is_user_registered(USER());

    assert(user_registered, 'User not registered');

    let user_id = dispatcher.get_user_id(USER());

    assert(user_id == id, 'Invalid user id');
}


#[test]
fn test_change_user_id() {
    let contract_address = deploy_contract("HelloWorld");

    let dispatcher = IHelloWorldDispatcher { contract_address };

    let old_id: felt252 = 'abc';
    let new_id: felt252 = 'def';

    start_cheat_caller_address(dispatcher.contract_address, USER());
    dispatcher.register_user(old_id);

    let user_id = dispatcher.get_user_id(USER());

    assert(user_id == old_id, 'Invalid user id');

    dispatcher.change_user_id(new_id);

    let user_id = dispatcher.get_user_id(USER());

    assert(user_id == new_id, 'Invalid user id');
    

    stop_cheat_caller_address(dispatcher.contract_address);

    
}

#[test]
#[should_panic(expected: 'User not registered')]
fn test_change_panics_when_user_not_registered() {
    let contract_address = deploy_contract("HelloWorld");

    let dispatcher = IHelloWorldDispatcher { contract_address };

    let new_id: felt252 = 'def';

    start_cheat_caller_address(dispatcher.contract_address, USER());
    dispatcher.change_user_id(new_id);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_unregister_user_as_user() {
    let contract_address = deploy_contract("HelloWorld");

    let dispatcher = IHelloWorldDispatcher { contract_address };

    let id: felt252 = 'abc';

    start_cheat_caller_address(dispatcher.contract_address, USER());
    dispatcher.register_user(id);

    let user_registered = dispatcher.is_user_registered(USER());

    assert(user_registered, 'User not registered');

    dispatcher.unregister_user(USER());

    let user_registered = dispatcher.is_user_registered(USER());

    assert(!user_registered, 'User not unregistered');
    
}

#[test]
fn test_unregister_user_as_owner() {
    let contract_address = deploy_contract("HelloWorld");

    let dispatcher = IHelloWorldDispatcher { contract_address };

    let id: felt252 = 'abc';

    start_cheat_caller_address(dispatcher.contract_address, USER());
    dispatcher.register_user(id);

    let user_registered = dispatcher.is_user_registered(USER());

    assert(user_registered, 'User not registered');

    stop_cheat_caller_address(dispatcher.contract_address);

    start_cheat_caller_address(dispatcher.contract_address, OWNER());
    dispatcher.unregister_user(USER());
    stop_cheat_caller_address(dispatcher.contract_address);

    let user_registered = dispatcher.is_user_registered(USER());

    assert(!user_registered, 'User not unregistered');
    
}

#[test]
#[should_panic(expected: 'Unauthorized')]
fn test_unregister_user_as_other_user() {
    let contract_address = deploy_contract("HelloWorld");

    let dispatcher = IHelloWorldDispatcher { contract_address };

    let id: felt252 = 'abc';

    start_cheat_caller_address(dispatcher.contract_address, USER());
    dispatcher.register_user(id);

    let user_registered = dispatcher.is_user_registered(USER());

    assert(user_registered, 'User not registered');

    stop_cheat_caller_address(dispatcher.contract_address);


    dispatcher.unregister_user(USER());
    
}


