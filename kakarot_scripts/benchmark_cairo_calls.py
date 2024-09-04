# %% Imports
import asyncio
import dataclasses

import numpy as np
import pandas as pd
import seaborn.objects as so

from kakarot_scripts.utils.kakarot import deploy as deploy_kakarot
from kakarot_scripts.utils.starknet import deploy as deploy_starknet
from kakarot_scripts.utils.starknet import invoke


# %% Main
async def main():

    # %% Deploy contracts
    cairo_contract = await deploy_starknet("BenchmarkCairoCalls")
    cairo_contract_caller = await deploy_kakarot(
        "CairoPrecompiles", "BenchmarkCairoCalls", cairo_contract["address"]
    )
    await invoke(
        "kakarot",
        "set_authorized_cairo_precompile_caller",
        int(cairo_contract_caller.address, 16),
        True,
    )

    # %% Generate data
    n_felts = np.unique(
        np.logspace(np.log10(1), np.log10(200), 100).astype(int)
    ).tolist()

    results = [
        await cairo_contract_caller.callCairoWithFeltInputs(n) for n in n_felts
    ] + [await cairo_contract_caller.callCairoWithBytesOutput(n) for n in n_felts]
    receipts = [
        {
            "gas_used": result["gas_used"],
            **dataclasses.asdict(result["receipt"].execution_resources),
        }
        for result in results
    ]

    # %% Compute statistics
    data = (
        pd.DataFrame(receipts)
        .drop("data_availability", axis=1)
        .fillna(0)
        .assign(
            function=len(n_felts) * ["callCairoWithFeltInputs"]
            + len(n_felts) * ["callCairoWithBytesOutput"],
            n_felts=n_felts * 2,
        )
    )

    p1 = (
        so.Plot(data, x="n_felts", y="steps")
        .add(so.Dots(), color="function")
        .scale(x="log", y="log")
    )
    p1.save("kakarot_scripts/data/cairo_calls_steps.png", bbox_inches="tight")


# %% Run
if __name__ == "__main__":
    asyncio.run(main())
