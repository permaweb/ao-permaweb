export function getTagValue(list: { [key: string]: any }[], name: string): string | null {
    for (let i = 0; i < list.length; i++) {
        if (list[i]) {
            if (list[i]!.name === name) {
                return list[i]!.value as string;
            }
        }
    }
    return null;
}