# @permaweb/sdk

This is the home of multiple building blocks that can be used to develop applications on the permaweb. Interactions with these building blocks are available via **@permaweb/sdk**

## Prerequisites

- `node >= v18.0`
- `npm` or `yarn`

## Installation

`npm install @permaweb/sdk`

or

`yarn add @permaweb/sdk`

## Usage

### Zones

Zones are a representation of an entity which contains information relevant to that entity and can carry out actions on that entity's behalf.

- `createZone() -> <ZoneId>`
- `getZone({ ZoneId }) -> <Zone>`

### Atomic Assets

Atomic assets are unique digital item consisting of an AO process and its associated data which are stored together in a single transaction on Arweave.

#### `createAtomicAsset({ Args }) -> <AssetId>`

Creates an atomic asset ([View implementation](./sdk/src/services/assets.ts#L6)).

```typescript
import { createAtomicAsset } from '@permaweb/sdk';

const assetId = await createAtomicAsset({
    title: 'Example Title',
    description, 'Example Description',
    type: 'Example Atomic Asset Type',
    topics: ['Topic 1', 'Topic 2', 'Topic 3'],
    contentType: 'text/html',
    data: '1234'
});
```

**Response**

```typescript
TxId
```

#### `getAtomicAsset({ AssetId }) -> <Asset>`

Performs a lookup of the atomic asset by ID ([View implementation](./sdk/src/services/assets.ts#L50)).

```typescript
import { getAtomicAsset } from "@permaweb/sdk";

const asset = await getAtomicAsset(AssetTxId);
```

**Response**

```typescript
 {
    id: 'TxId',
    title: 'Example Atomic Asset',
    description: 'Example Atomic Asset Description',
    dateCreated: 1678901234567,
    blockHeight: 1234567,
    renderWith: 'render-app',
    thumbnail: 'ThumbnailTxId',
    implementation: 'atomic-asset-v1',
    creator: 'ArweaveAddress',
    collectionId: 'CollectionTxId',
    contentType: 'text/html',
    udl: {
      access: { value: 'One-Time-0.5' },
      derivations: { value: 'Allowed-With-Credit-0.5' },
      commercialUse: { value: 'Allowed' },
      dataModelTraining: { value: 'Not-Allowed' },
      paymentMode: 'Global-Amount',
      paymentAddress: 'ArweaveAddress',
      currency: 'AR',
    }
 }
```
