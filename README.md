# Solidity Security — Reentrancy I

## Overview

This writeup explores advanced reentrancy vulnerabilities in Solidity smart contracts.

The goal is to understand how reentrancy can affect not only a single function but also multiple functions, interconnected contracts, and financial calculations based on temporarily inconsistent contract state.

Topics covered:

- Single-function Reentrancy
- Cross-function Reentrancy
- Cross-contract Reentrancy
- Read-only Reentrancy
- Callbacks and external interactions
- State invariants
- ReentrancyGuard limitations
- `nonReentrantView`
- Securing interconnected smart contracts

---

## 1. Single-function Reentrancy

Single-function reentrancy occurs when an external contract re-enters the same function before its previous execution has completed.

A typical vulnerable withdrawal function:

```solidity
function withdraw() external {
    uint256 amount = balances[msg.sender];

    require(amount > 0, "No balance");

    (bool success, ) = payable(msg.sender).call{value: amount}("");

    require(success, "Transfer failed");

    balances[msg.sender] = 0;
}
```

### Root cause

The contract performs an external interaction before updating its internal accounting.

During the external call, the recipient may execute a callback and re-enter `withdraw()` while the original balance is still available.

### Mitigation

Follow the Checks-Effects-Interactions (CEI) pattern:

1. Checks — validate all required conditions.
2. Effects — update the contract's internal state.
3. Interactions — perform external calls.

Example:

```solidity
function withdraw() external {
    uint256 amount = balances[msg.sender];

    require(amount > 0, "No balance");

    balances[msg.sender] = 0;

    (bool success, ) = payable(msg.sender).call{value: amount}("");

    require(success, "Transfer failed");
}
```

A `ReentrancyGuard` can provide an additional layer of protection.

---

## 2. Cross-function Reentrancy

Cross-function reentrancy occurs when an external callback enters a different function within the same contract while the original operation is still executing.

This becomes dangerous when multiple functions depend on shared state.

For example:

- `withdraw()` transfers funds.
- `claimReward()` checks the user's balance.
- Both functions depend on the same `balances` mapping.

If `withdraw()` performs an external call before updating the balance, `claimReward()` may observe outdated accounting information.

### Key lesson

Auditors must examine all functions that depend on shared state, not just the function containing the external call.

### Mitigation

- Apply CEI consistently.
- Protect related entry points with a shared `ReentrancyGuard`.
- Review state dependencies between functions.
- Enforce business logic invariants, such as one-time reward claims.

Example:

```solidity
function withdraw() external nonReentrant {
    // ...
}

function claimReward() external nonReentrant {
    // ...
}
```

Both functions must use the same guard instance.

---

## 3. Cross-contract Reentrancy

Cross-contract reentrancy involves multiple interconnected smart contracts.

A vulnerability may occur when an external interaction in one contract allows another contract to access an intermediate state or trigger an operation that depends on inconsistent accounting.

This is particularly relevant to DeFi architectures.

Example components:

- Vault — stores user assets.
- LendingPool — provides loans.
- Strategy — manages assets.
- External token contracts — may introduce callbacks.

### Root cause

Individual contracts may appear secure in isolation while their interactions create an unsafe execution sequence.

### Mitigation

- Analyze the complete external call graph.
- Identify shared financial invariants.
- Apply CEI across relevant state transitions.
- Protect critical entry points.
- Avoid relying on inconsistent data from interconnected contracts.

**Important:** A `ReentrancyGuard` only protects the contract instance in which it is implemented. It does not automatically provide system-wide protection.

---

## 4. Read-only Reentrancy

Read-only reentrancy occurs when an external contract reads temporarily inconsistent state during an unfinished operation and uses the returned data in its own financial calculations.

A `view` function does not need to modify state to become part of a vulnerability.

Consider a Vault with:

```solidity
uint256 public totalAssets;
uint256 public totalShares;
```

Share price:

```solidity
function pricePerShare()
    external
    view
    returns (uint256)
{
    return (totalAssets * 1e18) / totalShares;
}
```

Assume the initial state:

```text
totalAssets = 100 ETH
totalShares = 100
pricePerShare = 1 ETH
```

If `totalShares` is updated before an external interaction but `totalAssets` is updated afterward, the intermediate state could become:

```text
totalAssets = 100 ETH
totalShares = 50
pricePerShare = 2 ETH
```

The actual final share price should remain 1 ETH.

A LendingPool reading this intermediate value may incorrectly calculate collateral value and borrowing capacity.

### Mitigation

- Update all related accounting variables before external interactions.
- Maintain consistent state invariants.
- Use `nonReentrantView` where appropriate.
- Avoid relying on potentially inconsistent external price calculations.

### `nonReentrantView`

OpenZeppelin Contracts 5.x provides `nonReentrantView` in supported versions.

It prevents a protected view function from returning data while a corresponding reentrancy guard is active.

Example:

```solidity
function pricePerShare()
    external
    view
    nonReentrantView
    returns (uint256)
{
    return (totalAssets * 1e18) / totalShares;
}
```

The modifier is an additional protection mechanism, not a replacement for correct accounting and CEI.

Public autogenerated getters also require attention because they cannot simply be decorated with this modifier.

---

## 5. Callbacks and External Interactions

Reentrancy is not limited to ETH transfers using `.call()`.

External interactions and callback mechanisms can introduce additional entry points.

Examples include:

| Standard / Mechanism | Callback |
|---|---|
| ERC-721 | `onERC721Received` |
| ERC-1155 | `onERC1155Received` |
| ERC-777 | Token hooks |
| Flash Loans | Borrower callback |

Auditors should inspect all external interactions that can transfer execution control to another contract.

---

## 6. State Invariants

An invariant is a condition that should remain valid throughout the protocol's intended execution model.

Examples:

- Internal accounting must remain consistent with asset ownership.
- Outstanding shares must correspond to the assets they represent.
- A reward must not be claimable more times than intended.
- Borrowing capacity must be calculated using reliable collateral values.

A function can be individually correct while violating a larger protocol invariant.

This is why auditing requires understanding the entire system rather than reviewing isolated functions.

---

## 7. ReentrancyGuard Limitations

`ReentrancyGuard` is a useful defensive mechanism, but it has limitations.

1. It does not automatically protect unmodified functions.
2. Related functions must share the same guard instance.
3. It does not automatically protect other contracts.
4. It does not fix incorrect accounting.
5. It does not guarantee that external financial data is reliable.

CEI and correct state management remain fundamental.

---

## 8. Key Takeaways

The most important lessons from this study:

- Reentrancy is not limited to calling the same function repeatedly.
- Cross-function vulnerabilities can affect multiple functions sharing state.
- Cross-contract vulnerabilities require architectural analysis.
- Read-only functions can expose inconsistent intermediate state.
- Public getters may expose data that protected functions do not.
- External callbacks deserve special attention.
- ReentrancyGuard is an additional security layer, not a complete solution.
- Financial invariants must remain consistent across the entire protocol.

---

## Conclusion

Understanding reentrancy requires more than identifying external calls.

A security auditor must understand execution flow, shared state, callbacks, external dependencies, and financial invariants.

The most important principle:

**Secure smart contracts are not just collections of individually safe functions. They are systems whose state and interactions must remain consistent.**

*Study area: Solidity Security / Smart Contract Auditing*

*Environment: Solidity ^0.8.20, local educational examples*

*Status: Educational research and hands-on practice.*
