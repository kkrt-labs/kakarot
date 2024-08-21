import json

import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import numpy as np
from sklearn.linear_model import LinearRegression
from sklearn.metrics import r2_score


def load_data(filename):
    with open(filename, "r") as f:
        return json.load(f)


def format_func(value, pos):
    if value >= 1_000_000:
        return f"{value/1_000_000:.1f}M"
    elif value >= 1000:
        return f"{value:,.0f}"
    else:
        return f"{value:.0f}"


def fit_linear(x, y):
    linear_reg = LinearRegression()
    linear_reg.fit(x.reshape(-1, 1), y)
    return linear_reg


def plot_metric(data, fixed_tx_cost, metric_name, x_key, test_type):
    x_values = np.array([d[x_key] for d in data])
    metric_values = (
        np.array([d[metric_name] for d in data]) - fixed_tx_cost[metric_name]
    )

    # Fit linear regression
    linear_reg = fit_linear(x_values, metric_values)

    # Generate points for smooth curve
    X_smooth = np.linspace(0, x_values.max() * 1.2, 300).reshape(-1, 1)
    y_smooth = linear_reg.predict(X_smooth)

    plt.figure(figsize=(12, 7))
    plt.scatter(x_values, metric_values, color="blue", label="Data points")
    plt.plot(X_smooth, y_smooth, color="red", label="Fitted line")
    plt.xlabel(
        "Number of " + ("Input Felts" if test_type == "input_sizes" else "Output Bytes")
    )
    plt.ylabel(f'{metric_name.replace("_", " ").title()} (Base cost subtracted)')
    plt.title(
        f'{metric_name.replace("_", " ").title()} vs {x_key.replace("_", " ").title()} (Base cost subtracted)'
    )
    plt.ylim(bottom=0)

    ax = plt.gca()
    ax.yaxis.set_major_formatter(ticker.FuncFormatter(format_func))
    plt.grid(True)

    # Move legend outside the plot
    plt.legend(bbox_to_anchor=(1.05, 1), loc="upper left")

    # Display the formula
    m = linear_reg.coef_[0]
    b = linear_reg.intercept_
    formula = f"y = {m:.2f}x + {b:.2f}"
    plt.text(
        0.05,
        0.05,
        formula,
        transform=ax.transAxes,
        verticalalignment="bottom",
        fontsize=10,
    )

    # Adjust layout to make room for legend
    plt.tight_layout()
    plt.subplots_adjust(right=0.85)

    plt.savefig(
        f"kakarot_scripts/data/{test_type}_{metric_name}_plot.png",
        dpi=300,
        bbox_inches="tight",
    )
    plt.close()

    r2 = r2_score(metric_values, linear_reg.predict(x_values.reshape(-1, 1)))

    print(f"For {test_type}, {metric_name}:")
    print(f"Linear fit formula: {formula}")
    print(f"R-squared: {r2:.4f}")
    print(f"Slope (m): {m:.2f}")
    print(f"Y-intercept (b): {b:.2f}")
    print(f"Base transaction cost: {fixed_tx_cost[metric_name]}")
    print()


def main():
    data = load_data("kakarot_scripts/data/cairo_calls_benchmark_results.json")
    fixed_tx_cost = data["fixed_tx_cost"]
    metrics_to_plot = [
        "steps",
        # 'gas_used', 'memory_holes', 'range_check_builtin_applications',
        # 'pedersen_builtin_applications', 'ec_op_builtin_applications',
        # 'bitwise_builtin_applications', 'keccak_builtin_applications'
    ]
    for test_type in ["input_sizes", "output_sizes"]:
        x_key = "n_inputs" if test_type == "input_sizes" else "n_bytes_output"
        for metric in metrics_to_plot:
            plot_metric(data[test_type], fixed_tx_cost, metric, x_key, test_type)
    print("Plots have been saved as PNG files.")


if __name__ == "__main__":
    main()
