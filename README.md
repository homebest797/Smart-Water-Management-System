# Smart Water Management System

A comprehensive blockchain-based water management system built on Stacks using Clarity smart contracts.

## Overview

This system provides automated water management through five interconnected smart contracts that handle quality monitoring, billing, leak detection, conservation incentives, and emergency rationing.

## Contracts

### 1. Water Quality Monitoring (`water-quality.clar`)
- Tracks contamination levels and safety metrics
- Records pH, turbidity, and chemical contamination data
- Maintains quality history and alerts for unsafe conditions
- Provides quality certification for water sources

### 2. Usage Billing (`usage-billing.clar`)
- Calculates consumption charges automatically
- Tracks user water usage and generates bills
- Supports tiered pricing based on consumption levels
- Handles payment processing and billing history

### 3. Leak Detection (`leak-detection.clar`)
- Identifies pipeline breaks and water waste
- Monitors flow rates and pressure changes
- Generates alerts for suspected leaks
- Tracks repair status and maintenance records

### 4. Conservation Incentive (`conservation-incentive.clar`)
- Rewards users for reduced water consumption
- Calculates conservation bonuses and rebates
- Tracks conservation goals and achievements
- Manages incentive token distribution

### 5. Emergency Rationing (`emergency-rationing.clar`)
- Manages water supply during shortage periods
- Implements rationing quotas and restrictions
- Tracks emergency status and supply levels
- Coordinates distribution during crises

## Features

- **Real-time Monitoring**: Continuous tracking of water quality and usage
- **Automated Billing**: Smart contract-based billing with transparent pricing
- **Leak Prevention**: Early detection system to minimize water waste
- **Conservation Rewards**: Token-based incentives for water conservation
- **Emergency Management**: Automated rationing during supply shortages

## Data Types

- Water quality measurements (pH, turbidity, contamination levels)
- Usage metrics (consumption, flow rates, pressure)
- Billing information (rates, payments, balances)
- Conservation data (goals, achievements, rewards)
- Emergency status (rationing levels, supply availability)

## Getting Started

1. Install Clarinet CLI
2. Clone this repository
3. Run `clarinet check` to validate contracts
4. Run `npm test` to execute the test suite
5. Deploy contracts using `clarinet deploy`

## Testing

The system includes comprehensive tests using Vitest:
- Unit tests for each contract function
- Integration tests for cross-contract interactions
- Edge case testing for error conditions
- Performance tests for gas optimization

## Security

- Input validation on all contract functions
- Access control for administrative functions
- Safe arithmetic operations to prevent overflow
- Comprehensive error handling

## License

MIT License - see LICENSE file for details
