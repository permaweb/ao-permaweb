import { checkValidAddress } from './utils';

const arweaveEndpoint = 'https://arweave.net';

export function getARBalanceEndpoint(walletAddress: string) {
	return `${arweaveEndpoint}/wallet/${walletAddress}/balance`;
}

export function getTxEndpoint(txId: string) {
	return `${arweaveEndpoint}/${txId}`;
}

export function getRendererEndpoint(renderWith: string, tx: string) {
	if (checkValidAddress(renderWith)) {
		return `${arweaveEndpoint}/${renderWith}/?tx=${tx}`;
	} else {
		return `https://${renderWith}.arweave.net/?tx=${tx}`;
	}
}
