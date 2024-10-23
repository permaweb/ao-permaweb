import { getAtomicAsset } from '@permaweb/sdk';

// TODO
(async function () {
	const asset = await getAtomicAsset('z0f2O9Fs3yb_EMXtPPwKeb2O0WueIG5r7JLs5UxsA4I');
	console.log(asset)
})();