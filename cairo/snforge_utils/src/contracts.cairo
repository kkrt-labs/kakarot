#[starknet::interface]
trait IHello<T> {
    fn hello(self: @T);
    fn bar(self: @T);
}

#[starknet::contract]
mod HelloContract {
    use super::{IHelloDispatcher, IHelloDispatcherTrait};
    use core::starknet::get_contract_address;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn hello(self: @ContractState) {}

    #[external(v0)]
    fn bar(self: @ContractState) {
        IHelloDispatcher { contract_address: get_contract_address() }.hello();
    }
}

#[cfg(test)]
mod tests {
    use snforge_std::{declare, DeclareResultTrait, ContractClassTrait};
    use snforge_utils::snforge_utils::{assert_called, assert_called_with};
    use super::{IHelloDispatcher, IHelloDispatcherTrait};

    #[test]
    fn test_calltrace_entrypoint() {
        let helloclass = declare("HelloContract").unwrap().contract_class();
        let (hellocontract, _) = helloclass.deploy(@array![]).unwrap();

        IHelloDispatcher { contract_address: hellocontract }.hello();

        assert_called(hellocontract, selector!("hello"));
        assert_called_with::<()>(hellocontract, selector!("hello"), ());
    }

    #[test]
    fn test_calltrace_rec() {
        let helloclass = declare("HelloContract").unwrap().contract_class();
        let (hellocontract, _) = helloclass.deploy(@array![]).unwrap();

        IHelloDispatcher { contract_address: hellocontract }.bar();

        assert_called(hellocontract, selector!("hello"));
        assert_called_with::<()>(hellocontract, selector!("hello"), ());
    }
}
