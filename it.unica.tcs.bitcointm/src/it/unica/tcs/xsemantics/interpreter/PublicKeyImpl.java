/*
 * Copyright 2018 Nicola Atzei
 */

package it.unica.tcs.xsemantics.interpreter;

import java.util.Arrays;

import org.bitcoinj.core.NetworkParameters;

import it.unica.tcs.lib.utils.BitcoinUtils;

class PublicKeyImpl implements PublicKey {

    private final byte[] pubkey;
    private final Address address;

    public PublicKeyImpl(byte[] pubkey, NetworkParameters params) {
        this.pubkey = pubkey;
        this.address = Address.fromPubkey(pubkey, params);
    }

    @Override
    public byte[] getPublicKeyByte() {
        return pubkey;
    }

    @Override
    public String getPublicKeyString() {
        return BitcoinUtils.encode(pubkey);
    }

    @Override
    public byte[] getAddressByte() {
        return address.getAddressByte();
    }

    @Override
    public String getAddressWif() {
        return address.getAddressWif();
    }

    @Override
    public String getAddressString() {
        return address.getAddressString();
    }

    @Override
    public int hashCode() {
        final int prime = 31;
        int result = 1;
        result = prime * result + Arrays.hashCode(pubkey);
        return result;
    }

    @Override
    public boolean equals(Object obj) {
        if (this == obj)
            return true;
        if (obj == null)
            return false;
        if (getClass() != obj.getClass())
            return false;
        PublicKeyImpl other = (PublicKeyImpl) obj;
        if (!Arrays.equals(pubkey, other.pubkey))
            return false;
        return true;
    }
    
    @Override
    public String toString() {
        return getPublicKeyString();
    }
}
