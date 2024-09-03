import {TagType} from "./common";

export type APISpawnType = {
    module: string,
    scheduler: string,
    signer: any,
    tags: TagType[]
    data: any,
    wallet: any,
}

export type APISendType = {
    processId: string;
    wallet: any;
    action: string;
    tags: TagType[] | null;
    data: any;
    useRawData?: boolean;
}

export type APIResultType = {
    messageId: string;
    processId: string;
    messageAction: string;
}

export type APIDryRunType = {
    processId: string;
    tags: TagType[] | null;
    data: string;
    action: string;
}