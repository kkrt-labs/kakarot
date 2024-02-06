class TestStarknet:
    class TestGetEnv:
        def test_should_return_env_with_given_origin_and_gas_price(self, cairo_run):
            env = cairo_run("test__get_env", origin=1, gas_price=2)
            assert env["origin"] == 1
            assert env["gas_price"] == 2
