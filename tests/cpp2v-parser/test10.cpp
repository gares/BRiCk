int loops() {
    for (int i = 0; i < 10; i++) { }
    int k = 5;
    while (k--) {
        break;
    }

    k = 8;
    do {
        if (k == 12) continue;
    } while (k--);
    return k;
}