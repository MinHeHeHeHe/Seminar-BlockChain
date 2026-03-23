# 📊 Project Summary – DeFi Security Demo

---

## 🏗️ Kiến trúc hệ thống đã triển khai

### 1. Environment & Tooling Layer

* Cấu hình Foundry qua `foundry.toml`
* `package.json` kèm các script hỗ trợ chạy demo
* Hỗ trợ môi trường local với **Anvil** và **Hardhat node**
* Mẫu cấu hình biến môi trường

### 2. Protocol Simulation Layer

#### A. DEX Layer (AMM)

* `UniV2Factory.sol` – Factory dùng để tạo các pair
* `UniV2Pair.sol` – Pair contract hỗ trợ **flash swap**
* `UniV2Router.sol` – Router phục vụ add/remove liquidity và swap
* `StablePoolBuggy.sol` – Stable pool mô phỏng có lỗ hổng
* `StablePoolFixed.sol` – Phiên bản đã khắc phục
* Thư viện hỗ trợ: `Math.sol`, `UQ112x112.sol`
* Interface: `IUniV2Pair.sol`

#### B. Oracle Layer

* `OracleSpot.sol` – Oracle đọc trực tiếp reserves, dễ bị thao túng
* `OracleTWAP.sol` – Oracle dùng Time-Weighted Average Price an toàn hơn

#### C. Credit Layer

* `FlashLender.sol` – Flash loan provider theo phong cách Aave
* Tuân theo chuẩn ERC3156
* Có thể cấu hình mức phí

#### D. Target Protocols

* `LendingMock.sol` – Lending protocol dùng oracle, có chủ đích giữ lỗ hổng để demo
* `GovToken.sol` – Governance token dùng cho voting power
* `GovernanceWeak.sol` – Governance kiểm tra voting power tại thời điểm vote
* `VaultBuggy.sol` – Vault có lỗi accounting/share minting
* `VaultFixed.sol` – Phiên bản đã sửa lỗi

### 3. Attacker / Demo Layer

#### Attacker Contracts

* `Attacker_Oracle.sol` – Tấn công thao túng giá oracle

  * Flash swap để làm lệch reserves
  * Over-borrow từ lending protocol
  * Rút lợi nhuận từ chênh lệch định giá

* `Attacker_Governance.sol` – Tấn công chiếm quyền governance

  * Flash loan GOV token
  * Vote bằng voting power đi vay
  * Thực thi proposal độc hại

* `Attacker_PoolImbalance.sol` – Contract tổng hợp các exploit liên quan đến vault/pool

  * Share inflation attack
  * Donation front-run attack
  * Reentrancy attempts

#### Demo Scripts

* `Deploy.s.sol` – Triển khai toàn bộ hạ tầng mô phỏng
* `Demo_OracleAttack.s.sol` – Demo thao túng oracle
* `Demo_GovernanceAttack.s.sol` – Demo governance takeover
* `Demo_PoolAttack.s.sol` – Demo các exploit liên quan đến vault/pool

### 4. Utilities

* `MockERC20.sol` – Token ERC20 phục vụ test và mô phỏng

---

## 🎯 Các hướng tấn công đã triển khai

### 1. Oracle Price Manipulation

**Lỗ hổng:** Spot price oracle có thể bị thao túng trong cùng transaction.

**Thành phần liên quan:**

* Vulnerable: `OracleSpot.sol`
* Secure: `OracleTWAP.sol`
* Target: `LendingMock.sol`
* Attacker: `Attacker_Oracle.sol`
* Demo: `Demo_OracleAttack.s.sol`

**Luồng tấn công:**

1. Attacker dùng flash swap từ DEX để làm lệch reserves
2. Oracle spot đọc mức giá sai lệch
3. Lending protocol định giá collateral sai
4. Attacker vay vượt mức cho phép
5. Hoàn trả flash swap và giữ phần lợi nhuận

**Biện pháp khắc phục:**
Sử dụng **TWAP** thay vì spot price.

---

### 2. Governance Takeover

**Lỗ hổng:** Voting power được kiểm tra tại thời điểm vote, không dùng snapshot trước đó.

**Thành phần liên quan:**

* Vulnerable: `GovernanceWeak.sol`
* Token: `GovToken.sol`
* Credit: `FlashLender.sol`
* Attacker: `Attacker_Governance.sol`
* Demo: `Demo_GovernanceAttack.s.sol`

**Luồng tấn công:**

1. Attacker flash loan một lượng lớn GOV token
2. Dùng lượng token đi vay để vote cho proposal
3. Hoàn trả flash loan trong cùng transaction
4. Sau đó execute proposal độc hại

**Kết quả đạt được:**
Attacker có thể biến voting power tạm thời thành quyền quản trị thực sự, ví dụ chiếm ownership của contract mục tiêu.

**Biện pháp khắc phục:**
Dùng **snapshot-based voting**.

---

### 3. Vault Share Inflation

**Lỗ hổng:** Vault không xử lý an toàn trường hợp first deposit và không burn minimum shares.

**Thành phần liên quan:**

* Vulnerable: `VaultBuggy.sol`
* Secure: `VaultFixed.sol`
* Attacker: `Attacker_PoolImbalance.sol`
* Demo: `Demo_PoolAttack.s.sol`

**Luồng tấn công:**

1. Attacker trở thành first depositor với lượng cực nhỏ
2. Donate thêm lượng tài sản lớn để đẩy giá trị mỗi share lên cao bất thường
3. Victim deposit nhưng do lỗi rounding nên nhận `0 shares`
4. Attacker rút toàn bộ tài sản trong vault

**Biện pháp khắc phục:**
Burn minimum shares theo hướng **Uniswap V2 style** và bổ sung kiểm tra accounting an toàn.

---

## 🎓 Learning Outcomes

Sau khi hoàn thành dự án này, người thực hiện có thể hiểu và thực hành được:

1. Cách hoạt động của DEX theo mô hình Uniswap V2
2. Cơ chế flash swap và flash loan
3. Các lỗ hổng phổ biến trong oracle design
4. Cách governance có thể bị khai thác
5. Các lỗi accounting và share minting trong vault
6. Quy trình xây dựng demo cho các DeFi exploit phổ biến
7. Các hướng phòng vệ để tăng độ an toàn cho protocol

---
