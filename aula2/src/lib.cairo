// Ajustes e revisão das funções que contém ownable
use starknet::ContractAddress;

#[starknet::interface]
pub trait IHelloWorld<TContractState> {
    // Registro de usuários
    fn register_user(ref self: TContractState, id: felt252);
    fn unregister_user(ref self: TContractState, user: ContractAddress);
    fn change_user_id(ref self: TContractState, id: felt252);

    // Getters
    fn is_user_registered(self: @TContractState, user: ContractAddress) -> bool;
    fn get_user_id(self: @TContractState, user: ContractAddress) -> felt252;
    fn get_users_count(self: @TContractState) -> u64;

    // Depósito e saque
    fn deposity(ref self: TContractState, amount: u256);
    fn withdraw(ref self: TContractState, amount: u256);

    // Consultas de saldo
    fn userBalance(self: @TContractState, user: ContractAddress) -> u256;
    fn myBalance(self: @TContractState) -> u256;
    fn contractBalance(self: @TContractState) -> u256;
}

#[starknet::contract]
mod HelloWorld {
    use openzeppelin::access::ownable::ownable;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};

    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, Map};
    use core::starknet::{ContractAddress, get_caller_address, get_contract_address};

    // Componente do Ownable
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        ids: Map<ContractAddress, felt252>,
        users_registered: Map<ContractAddress, bool>,
        user_balance: Map<ContractAddress, u256>,
        this_balance: u256,
        users_count: u64,
        ERC20_addr: ContractAddress,
        #[substorage(v0)]
        pub ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        UserRegistered: UserRegistered,
        UserUnregistered: UserUnregistered,
        UserIdChanged: UserIdChanged,
        Deposity: Deposity,
        Withdraw: Withdraw,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct UserRegistered {
        pub user: ContractAddress,
        pub id: felt252,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct UserUnregistered {
        pub user: ContractAddress,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct UserIdChanged {
        pub user: ContractAddress,
        pub id: felt252,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct Deposity {
        pub user: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct Withdraw {
        pub user: ContractAddress,
        pub amount: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, ERC20_addr: ContractAddress) {
        use openzeppelin::access::ownable::ownable;
        ownable::initializer(self.ownable, owner);
        self.ERC20_addr.write(ERC20_addr);
    }

    #[abi(embed_v0)]
    impl HelloWorldImpl of super::IHelloWorld<ContractState> {
        fn register_user(ref self: ContractState, id: felt252) {
            let caller = get_caller_address();
            self.users_registered.entry(caller).write(true);
            self.ids.entry(caller).write(id);
            self.users_count.write(self.users_count.read() + 1);

            self.emit(UserRegistered { user: caller, id });
        }

        fn unregister_user(ref self: ContractState, user: ContractAddress) {
            let caller = get_caller_address();
            let owner = self.ownable.owner();
            assert(caller == user || caller == owner, 'Unauthorized');

            let is_registered = self.users_registered.entry(user).read();
            assert(is_registered, 'User not registered');
            assert(self.users_count.read() > 0, 'No users registered');

            self.users_count.write(self.users_count.read() - 1);
            self.users_registered.entry(user).write(false);

            self.emit(UserUnregistered { user });
        }

        fn change_user_id(ref self: ContractState, id: felt252) {
            let caller = get_caller_address();
            let registered = self.users_registered.entry(caller).read();
            assert(registered, 'User not registered');

            self.ids.entry(caller).write(id);

            self.emit(UserIdChanged { user: caller, id });
        }

        fn get_users_count(self: @ContractState) -> u64 {
            self.users_count.read()
        }

        fn is_user_registered(self: @ContractState, user: ContractAddress) -> bool {
            self.users_registered.entry(user).read()
        }

        fn get_user_id(self: @ContractState, user: ContractAddress) -> felt252 {
            self.ids.entry(user).read()
        }

        fn deposity(ref self: ContractState, amount: u256) {
            let caller = get_caller_address();
            let erc20 = ERC20ABIDispatcher { contract_address: self.ERC20_addr.read() };

            let caller_balance_here = self.user_balance.entry(caller).read();
            let caller_erc20_balance = erc20.balance_of(caller);
            assert(caller_erc20_balance >= amount, 'Insufficient balance');

            erc20.transfer_from(caller, get_contract_address(), amount);

            self.user_balance.entry(caller).write(caller_balance_here + amount);
            self.this_balance.write(self.this_balance.read() + amount);

            self.emit(Deposity { user: caller, amount });
        }

        fn withdraw(ref self: ContractState, amount: u256) {
            let caller = get_caller_address();
            let erc20 = ERC20ABIDispatcher { contract_address: self.ERC20_addr.read() };

            let caller_balance = self.user_balance.entry(caller).read();
            let contract_balance = self.this_balance.read();
            assert(caller_balance >= amount, 'Insufficient balance');
            assert(contract_balance >= amount, 'Insufficient contract balance');

            erc20.transfer(caller, amount);

            self.user_balance.entry(caller).write(caller_balance - amount);
            self.this_balance.write(contract_balance - amount);

            self.emit(Withdraw { user: caller, amount });
        }

        fn userBalance(self: @ContractState, user: ContractAddress) -> u256 {
            self.user_balance.entry(user).read()
        }

        fn myBalance(self: @ContractState) -> u256 {
            let caller = get_caller_address();
            self.user_balance.entry(caller).read()
        }

        fn contractBalance(self: @ContractState) -> u256 {
            self.this_balance.read()
        }
    }
}
