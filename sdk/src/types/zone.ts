import { TagType } from 'types/helpers';

export type APICreateZone = {
	module: string;
	scheduler: string;
	wallet: string;
	tags: TagType[];
	data: any;
};
