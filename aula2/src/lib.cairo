use starknet::ContractAddress;

#[starknet::interface]
pub trait IHelloWorld<TContractState> {
    fn register_user(ref self: TContractState, id: felt252);
    fn unregister_user(ref self: TContractState, user: ContractAddress);
    fn change_user_id(ref self: TContractState, id: felt252);

    // get
    fn is_user_registered(self: @TContractState, user: ContractAddress) -> bool;
    fn get_user_id(self: @TContractState, user: ContractAddress) -> felt252;
    fn get_users_count(self: @TContractState) -> u64;

    // aula 3
    fn deposity(ref self: TContractState, amount: u256);
    fn withdraw(ref self: TContractState, amount: u256);
    fn userBalance(self: @TContractState, user: ContractAddress) -> u256;
    fn myBalance(self: @TContractState) -> u256;
    fn contractBalance(self: @TContractState) -> u256;

    // NOVA FUNCIONALIDADE
    fn send_message(ref self: TContractState, to: ContractAddress, content: felt252);
    fn read_message(self: @TContractState, from: ContractAddress) -> felt252;
}

#[starknet::contract]
mod HelloWorld {
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, Map};
    use core::starknet::{ContractAddress, get_caller_address, get_contract_address};

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
        messages: Map<(ContractAddress, ContractAddress), felt252>,
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
        MessageSent: MessageSent,
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

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct MessageSent {
        pub from: ContractAddress,
        pub to: ContractAddress,
        pub content: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, ERC20_addr: ContractAddress) {
        self.ownable.initializer(owner);
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
            assert(self.users_registered.entry(user).read(), 'User not registered');
            assert(self.users_count.read() > 0, 'No users registered');
            self.users_count.write(self.users_count.read() - 1);
            self.users_registered.entry(user).write(false);
            self.emit(UserUnregistered { user });
        }

        fn change_user_id(ref self: ContractState, id: felt252) {
            let caller = get_caller_address();
            assert(self.users_registered.entry(caller).read(), 'User not registered');
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
            assert(erc20.balance_of(caller) >= amount, 'Insufficient balance');
            erc20.transfer_from(caller, get_contract_address(), amount);
            self.user_balance.entry(caller).write(self.user_balance.entry(caller).read() + amount);
            self.this_balance.write(self.this_balance.read() + amount);
            self.emit(Deposity { user: caller, amount });
        }

        fn withdraw(ref self: ContractState, amount: u256) {
            let caller = get_caller_address();
            let erc20 = ERC20ABIDispatcher { contract_address: self.ERC20_addr.read() };
            assert(self.user_balance.entry(caller).read() >= amount, 'Insufficient balance');
            assert(self.this_balance.read() >= amount, 'Insufficient contract balance');
            erc20.transfer(caller, amount);
            self.user_balance.entry(caller).write(self.user_balance.entry(caller).read() - amount);
            self.this_balance.write(self.this_balance.read() - amount);
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

        // NOVAS FUNÇÕES

        fn send_message(ref self: ContractState, to: ContractAddress, content: felt252) {
            let from = get_caller_address();
            assert(self.users_registered.entry(from).read(), 'Sender not registered');
            assert(self.users_registered.entry(to).read(), 'Recipient not registered');
            self.messages.entry((from, to)).write(content);
            self.emit(MessageSent { from, to, content });
        }

        fn read_message(self: @ContractState, from: ContractAddress) -> felt252 {
            let to = get_caller_address();
            assert(self.users_registered.entry(from).read(), 'Sender not registered');
            assert(self.users_registered.entry(to).read(), 'Recipient not registered');
            self.messages.entry((from, to)).read()
        }
    }
}
