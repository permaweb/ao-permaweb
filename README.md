# @permaweb/libs

This is the home of multiple libraries designed as building blocks for developers to create and interact with applications on Arweave's permaweb. This SDK simplifies the process of working with atomic assets, profiles, collections, and more, enabling you to seamlessly build decentralized, permanent applications. With its versatile modules, you can manage digital items, represent entities, and carry out secure and trustless interactions on the permaweb. The SDK provides the flexibility and foundation needed to implement decentralized web applications effectively.

## Prerequisites

- `node >= v18.0`
- `npm` or `yarn`

## Installation

`npm install @permaweb/libs`

or

`yarn add @permaweb/libs`

## Usage

### Zones

Zones are a representation of an entity which contains information relevant to that entity and can carry out actions on that entity's behalf.

#### `createZone`

Creates a zone. ([View implementation](./sdk/src/services/zones.ts#L5))

```typescript
import { createZone } from "@permaweb/libs";

const zoneId = await createZone(wallet, (status) => console.log(status));
```

**Response**

```typescript
ZoneProcessId;
```

#### `updateZone`

Updates a zone's key value store. ([View implementation](./sdk/src/services/zones.ts#L21))

```typescript
import { updateZone } from "@permaweb/libs";

const zoneUpdateId = await updateZone(
  {
    zoneId: zoneId,
    data: {
      name: 'Sample Zone',
      metadata: {
        description: 'A test zone for unit testing',
        version: '1.0.0',
      },
    },
  },
  wallet
);
```

**Response**

```typescript
ZoneUpdateId;
```

#### `getZone`

Fetches a zone. ([View implementation](./sdk/src/services/zones.ts#L39))

```typescript
import { getZone } from "@permaweb/libs";

const zone = await getZone(zoneId);
```

**Response**

```typescript
{ store: [], assets: [] }
```

### Atomic Assets

Atomic assets are unique digital item consisting of an AO process and its associated data which are stored together in a single transaction on Arweave.

#### `createAtomicAsset`

Creates an atomic asset. ([View implementation](./sdk/src/services/assets.ts#L8))

```typescript
import { createAtomicAsset } from '@permaweb/libs';

const assetId = await createAtomicAsset({
    title: 'Example Title',
    description, 'Example Description',
    type: 'Example Atomic Asset Type',
    topics: ['Topic 1', 'Topic 2', 'Topic 3'],
    contentType: 'text/html',
    data: '1234'
}, wallet, (status) => console.log(status));
```

**Response**

```typescript
AssetProcessId;
```

#### `getAtomicAsset`

Performs a lookup of an atomic asset by ID. This function also performs a dryrun on the asset process to receive the balances and other associated metadata of the atomic asset that is inside the AO process itself. ([View implementation](./sdk/src/services/assets.ts#L50))

```typescript
import { getAtomicAsset } from "@permaweb/libs";

const asset = await getAtomicAsset(AssetTxId);
```

**Response**

```typescript
 {
  id: 'z0f2O9Fs3yb_EMXtPPwKeb2O0WueIG5r7JLs5UxsA4I',
  title: 'City',
  description: 'A collection of AI generated images of different settings and areas',
  type: null,
  topics: null,
  contentType: 'image/png',
  renderWith: null,
  thumbnail: null,
  udl: {
    access: { value: 'One-Time-0.1' },
    derivations: { value: 'Allowed-With-One-Time-Fee-0.1' },
    commercialUse: { value: 'Allowed-With-One-Time-Fee-0.1' },
    dataModelTraining: { value: 'Disallowed' },
    paymentMode: 'Single',
    paymentAddress: 'uf_FqRvLqjnFMc8ZzGkF4qWKuNmUIQcYP0tPlCGORQk',
    currency: 'xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10'
  },
  creator: 'SaXnsUgxJLkJRghWQOUs9-wB0npVviewTkUbh2Yk64M',
  collectionId: 'XcfPzHzxt2H8FC03MAC_78U1YwO9Gdk72spbq70NuNc',
  implementation: 'ANS-110',
  dateCreated: 1717663091000,
  blockHeight: 1439467,
  ticker: 'ATOMIC',
  denomination: '1',
  balances: {
    'SaXnsUgxJLkJRghWQOUs9-wB0npVviewTkUbh2Yk64M': '1',
    cfQOZc7saMMizHtBKkBoF_QuH5ri0Bmb5KSf_kxQsZE: '1',
    U3TjJAZWJjlWBB4KAXSHKzuky81jtyh0zqH8rUL4Wd0: '98'
  },
  transferable: true
}
```

#### `getAtomicAssets({ ids: AssetTxId[] })`

Performs a lookup of atomic assets. ([View implementation](./sdk/src/services/assets.ts#L50))

```typescript
import { getAtomicAssets } from "@permaweb/libs";

const assets = await getAtomicAssets({
  ids: ["AssetTxId1", "AssetTxId2", "AssetTxId3"],
});
```

**Response**

```typescript
[
  {
    id: "z0f2O9Fs3yb_EMXtPPwKeb2O0WueIG5r7JLs5UxsA4I",
    title: "City",
    description:
      "A collection of AI generated images of different settings and areas",
    type: null,
    topics: null,
    contentType: "image/png",
    renderWith: null,
    thumbnail: null,
    udl: {
      access: { value: "One-Time-0.1" },
      derivations: { value: "Allowed-With-One-Time-Fee-0.1" },
      commercialUse: { value: "Allowed-With-One-Time-Fee-0.1" },
      dataModelTraining: { value: "Disallowed" },
      paymentMode: "Single",
      paymentAddress: "uf_FqRvLqjnFMc8ZzGkF4qWKuNmUIQcYP0tPlCGORQk",
      currency: "xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10",
    },
    creator: "SaXnsUgxJLkJRghWQOUs9-wB0npVviewTkUbh2Yk64M",
    collectionId: "XcfPzHzxt2H8FC03MAC_78U1YwO9Gdk72spbq70NuNc",
    implementation: "ANS-110",
    dateCreated: 1717663091000,
    blockHeight: 1439467,
  },
];
```
