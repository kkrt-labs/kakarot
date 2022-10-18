from typing import List, Tuple
from unittest import IsolatedAsyncioTestCase
from asyncio import run
from marshmallow_dataclass import dataclass
from starkware.starknet.testing.starknet import Starknet
from cairo_coverage import cairo_coverage


@dataclass
class Uint256:
    """Uint256 dataclass to ease the asserting process"""

    __slots__ = ("low", "high")
    low: int  # 2**128 low bits
    high: int  # 2**128 high bits

    def __eq__(self, __o: object) -> bool:
        """__eq__ method allows to do a == b (a and b being Uints256)"""
        return self.low == __o.low and self.high == __o.high


def hex_string_to_int_array(text):
    return [int(text[i : i + 2], 16) for i in range(0, len(text), 2)]


def get_case(case: str) -> Tuple[List[int], List[int]]:
    from json import load

    with open(case, "r") as f:
        test_case_data = load(f)
    return hex_string_to_int_array(test_case_data["code"]), hex_string_to_int_array(
        test_case_data["calldata"]
    )


class TestBasic(IsolatedAsyncioTestCase):
    @classmethod
    def setUpClass(cls) -> None:
        async def _setUpClass(cls) -> None:
            cls.starknet = await Starknet.empty()
            cls.zk_evm = await cls.starknet.deploy(
                source="./src/kakarot/kakarot.cairo",
                cairo_path=["src"],
                disable_hint_validation=True,
                constructor_calldata=[1],
            )

        run(_setUpClass(cls))

    @classmethod
    def tearDownClass(cls):
        cairo_coverage.report_runs(excluded_file={".local"})

    async def test_arithmetic_operations(self):
        code, calldata = get_case(case="./tests/cases/001.json")

        res = await self.zk_evm.execute(code=[*code], calldata=[*calldata]).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(16, 0))
        self.assertEqual(res.result.top_memory, Uint256(0, 0))

    async def test_comparison_operations(self):
        async def assert_compare(self, case: str, expected: Uint256):
            code, calldata = get_case(case=f"./tests/cases/003_{case}.json")

            res = await self.zk_evm.execute(code=[*code], calldata=[*calldata]).execute(
                caller_address=1
            )
            self.assertEqual(res.result.top_stack, expected)
            self.assertEqual(res.result.top_memory, Uint256(0, 0))

        await assert_compare(self, "lt", Uint256(0, 0))
        await assert_compare(self, "gt", Uint256(1, 0))
        await assert_compare(self, "slt", Uint256(1, 0))
        await assert_compare(self, "sgt", Uint256(0, 0))

    async def test_duplication_operations(self):
        code, calldata = get_case(case="./tests/cases/002.json")
        res = await self.zk_evm.execute(code=[*code], calldata=[*calldata]).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(3, 0))
        self.assertEqual(res.result.top_memory, Uint256(0, 0))

    async def test_memory_operations(self):
        code, calldata = get_case(case="./tests/cases/004.json")
        res = await self.zk_evm.execute(code=[*code], calldata=[*calldata]).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(0, 0))
        self.assertEqual(res.result.top_memory, Uint256(10, 0))

    async def test_exchange_operations(self):
        code, calldata = get_case(case="./tests/cases/005.json")
        res = await self.zk_evm.execute(code=[*code], calldata=[*calldata]).execute(
            caller_address=1
        )
        self.assertEqual(res.result.top_stack, Uint256(4, 0))
        self.assertEqual(res.result.top_memory, Uint256(0, 0))
