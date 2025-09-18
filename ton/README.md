# Hadron Vault on TON (Unus Nullus UAB)

This module mirrors the Hadron (EVM) architecture for the TON blockchain, using Tact for smart contracts.

- Core vault: tokenized strategy vault with pluggable protocol adapters ("gluons")
- Gluons: protocol-specific adapters executed by the vault
- Pre-hooks: optional checks executed before sensitive calls
- Access control: role-based gating for admin and operator actions

## Architecture Schema (TON)

```mermaid
flowchart LR
  subgraph User/Offchain
    U[User / Frontend]
  end

  subgraph Hadron_TON_Core
    HV[HadronVault (TON)]
    PH[PreHooks]
  end

  subgraph Gluons (protocol adapters)
    G1[Balance Gluons]
    G2[Market Action Gluons]
    G3[Rewards Gluons]
  end

  subgraph Access_Control
    AM[Access Control]
  end

  subgraph External_Protocols
    P1[(DEX / Lending / Bridges on TON)]
  end

  U -->|deposit/mint| HV
  U -->|withdraw/redeem| HV
  U -->|execute(actions)| HV

  HV --> PH
  HV --> G1
  HV --> G2
  HV --> G3

  G1 --> P1
  G2 --> P1
  G3 --> P1

  HV --> AM
```

## Repo Layout

```
ton/
  contracts/
    HadronVault.tact
    gluons/
      IGluon.tact
      ExampleBalanceGluon.tact
    access/
      AccessControl.tact
    prehooks/
      PreHooks.tact
  README.md
  package.json
  tact.config.json
```

## Build & Test

- Install Tact toolchain: `npm i -g tact-cli`
- Install deps in this module: `npm i`
- Build: `npm run build`
- Test (placeholder): `npm run test`

## Notes

- Storage and execution semantics differ from EVM; the design mirrors concepts, not bytecode.
- Gluon interfaces and pre-hook registry follow the same patterns for modularity.
