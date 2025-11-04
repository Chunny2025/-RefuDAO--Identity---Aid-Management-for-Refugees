# Identity & Aid Management for Refugees

## 🎯 Overview
RefuDAO is a decentralized solution for managing refugee identities and aid distribution using blockchain technology. The system enables trusted NGOs to verify refugee identities and coordinate aid disbursement through a transparent DAO structure.

## ✨ Features
- 🆔 Self-sovereign identity management for refugees
- 🏢 NGO verification system
- 💰 Transparent aid pool management
- 🗳️ Democratic aid distribution through proposals
- 📊 Aid tracking and reporting
- 🔄 Dynamic refugee status management
- 🚨 Emergency aid distribution for critical situations

## 🚀 Getting Started

### Prerequisites
- Clarinet
- Stacks wallet

### Contract Functions

#### For Administrators
- `register-ngo`: Register trusted NGO organizations
- `deposit-aid`: Add funds to the aid pool
- `emergency-aid`: Provide immediate aid to eligible refugees bypassing proposal process

#### For NGOs
- `register-refugee`: Register and verify refugee identities
- `update-refugee-status`: Update refugee active status
- `create-aid-proposal`: Create proposals for aid distribution
- `vote-proposal`: Vote on existing aid proposals
- `execute-proposal`: Execute approved aid proposals

#### Read-Only Functions
- `get-refugee-data`: View refugee registration data
- `get-proposal`: View proposal details
- `get-aid-pool-balance`: Check available aid pool balance

## 🔒 Security
- Multi-signature requirement for aid distribution
- Verified NGO-only access to key functions
- Transparent transaction history

## 🤝 Contributing
Contributions are welcome! Please feel free to submit a Pull Request.
```

Git commit message:
```
feat: implement RefuDAO MVP with identity verification and aid distribution
```

PR Title:
```
✨ MVP: RefuDAO Identity & Aid Management System
```

PR Description:
```
This PR introduces the initial MVP for RefuDAO, implementing core functionality for refugee identity management and aid distribution.

Key Features:
- NGO verification system
- Refugee identity registration
- Aid proposal creation and voting
- Secure aid distribution mechanism
- Balance tracking and reporting

The implementation focuses on essential features while maintaining security and transparency in aid distribution.

Testing completed:
- Contract deployment
- NGO registration
- Refugee registration
- Aid proposal workflow
- Fund distribution

Next steps:
- Add additional security measures
- Implement event logging
- Expand reporting capabilities

