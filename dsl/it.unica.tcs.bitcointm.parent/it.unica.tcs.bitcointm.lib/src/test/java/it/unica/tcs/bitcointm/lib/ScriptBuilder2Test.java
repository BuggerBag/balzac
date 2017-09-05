package it.unica.tcs.bitcointm.lib;

import static org.junit.Assert.assertEquals;

import org.bitcoinj.core.ECKey;
import org.bitcoinj.core.Transaction;
import org.bitcoinj.core.Transaction.SigHash;
import org.bitcoinj.core.TransactionInput;
import org.bitcoinj.params.MainNetParams;
import org.junit.Test;

public class ScriptBuilder2Test {

	@Test
    public void test_size() {
        ScriptBuilder2 sb = new ScriptBuilder2();
        assertEquals(0, sb.size());
        assertEquals(0, sb.freeVariableSize());
        assertEquals(0, sb.signatureSize());
        sb.number(5);
        assertEquals(1, sb.size());
        assertEquals(0, sb.freeVariableSize());
        assertEquals(0, sb.signatureSize());
    }
    
    @Test
    public void test_freeVariable() {
        ScriptBuilder2 sb = new ScriptBuilder2();
        assertEquals(0, sb.size());
        assertEquals(0, sb.freeVariableSize());
        assertEquals(0, sb.signatureSize());
        sb.freeVariable("pippo", Integer.class);
        assertEquals(1, sb.size());
        assertEquals(1, sb.freeVariableSize());
        assertEquals(0, sb.signatureSize());
        sb = sb.setFreeVariable("pippo", 5);
        assertEquals(1, sb.size());
        assertEquals(0, sb.freeVariableSize());
        assertEquals(0, sb.signatureSize());
    }
    
    @Test
    public void test_signature() {
        ScriptBuilder2 sb = new ScriptBuilder2();
        assertEquals(0, sb.size());
        assertEquals(0, sb.freeVariableSize());
        assertEquals(0, sb.signatureSize());
        sb.signaturePlaceholder(new ECKey(), SigHash.ALL, false);
        assertEquals(1, sb.size());
        assertEquals(0, sb.freeVariableSize());
        assertEquals(1, sb.signatureSize());
        Transaction tx = new Transaction(new MainNetParams());
        tx.addInput(new TransactionInput(new MainNetParams(), null, new byte[]{42,42}));
        sb = sb.setSignatures(tx, 0, new byte[]{});
        assertEquals(1, sb.size());
        assertEquals(0, sb.freeVariableSize());
        assertEquals(0, sb.signatureSize());
    }
    
    @Test(expected=IllegalStateException.class)
    public void test_appendFail() {
        ScriptBuilder2 sb = new ScriptBuilder2();
        sb.freeVariable("pippo", Integer.class);
        new ScriptBuilder2().append(sb);
    }

    @Test
    public void test_serialize_freeVariable() {
    	ScriptBuilder2 sb = new ScriptBuilder2();
    	sb.number(15);
    	sb.freeVariable("Donald", String.class);
    	String expected = "15 [var,Donald,java.lang.String]"; 
    	String actual = ScriptBuilder2.serialize(sb);
    	assertEquals(expected, actual);
    }
    
    @Test
    public void test_derialize_freeVariable() {
    	String serialScript = "15 [var,Donald,java.lang.String]"; 
    	ScriptBuilder2 res = ScriptBuilder2.deserialize(serialScript);

    	assertEquals(1, res.freeVariableSize());
    	assertEquals(2, res.size());
    	assertEquals(String.class, res.getFreeVariables().get("Donald"));
    }
    
    @Test
    public void test_serialize_signature1() {
    	ECKey key = new ECKey();
    	SigHash hashType = SigHash.ALL;
    	ScriptBuilder2 sb = new ScriptBuilder2();
    	sb.number(15);
    	sb.signaturePlaceholder(key, hashType, false);
    	
    	String expected = "15 [sig,"+key.getPrivateKeyAsHex()+",**]"; 
    	String actual = ScriptBuilder2.serialize(sb);
    	assertEquals(expected, actual);
    }

    @Test
    public void test_serialize_signature2() {
    	ECKey key = new ECKey();
    	SigHash hashType = SigHash.ALL;
    	ScriptBuilder2 sb = new ScriptBuilder2();
    	sb.number(15);
    	sb.signaturePlaceholder(key, hashType, true);
    	
    	String expected = "15 [sig,"+key.getPrivateKeyAsHex()+",1*]"; 
    	String actual = ScriptBuilder2.serialize(sb);
    	assertEquals(expected, actual);
    }
    
    @Test
    public void test_serialize_signature3() {
    	ECKey key = new ECKey();
    	SigHash hashType = SigHash.SINGLE;
    	ScriptBuilder2 sb = new ScriptBuilder2();
    	sb.number(15);
    	sb.signaturePlaceholder(key, hashType, false);
    	
    	String expected = "15 [sig,"+key.getPrivateKeyAsHex()+",*1]"; 
    	String actual = ScriptBuilder2.serialize(sb);
    	assertEquals(expected, actual);
    }

    @Test
    public void test_serialize_signature4() {
    	ECKey key = new ECKey();
    	SigHash hashType = SigHash.SINGLE;
    	ScriptBuilder2 sb = new ScriptBuilder2();
    	sb.number(15);
    	sb.signaturePlaceholder(key, hashType, true);
    	
    	String expected = "15 [sig,"+key.getPrivateKeyAsHex()+",11]"; 
    	String actual = ScriptBuilder2.serialize(sb);
    	assertEquals(expected, actual);
    }
    
    @Test
    public void test_serialize_signature5() {
    	ECKey key = new ECKey();
    	SigHash hashType = SigHash.NONE;
    	ScriptBuilder2 sb = new ScriptBuilder2();
    	sb.number(15);
    	sb.signaturePlaceholder(key, hashType, false);
    	
    	String expected = "15 [sig,"+key.getPrivateKeyAsHex()+",*0]"; 
    	String actual = ScriptBuilder2.serialize(sb);
    	assertEquals(expected, actual);
    }

    @Test
    public void test_serialize_signature6() {
    	ECKey key = new ECKey();
    	SigHash hashType = SigHash.NONE;
    	ScriptBuilder2 sb = new ScriptBuilder2();
    	sb.number(15);
    	sb.signaturePlaceholder(key, hashType, true);
    	
    	String expected = "15 [sig,"+key.getPrivateKeyAsHex()+",10]"; 
    	String actual = ScriptBuilder2.serialize(sb);
    	assertEquals(expected, actual);
    }
    @Test
    public void test_derialize_signature() {
    	ECKey key = new ECKey();
    	String serialScript = "15 [sig,"+key.getPrivateKeyAsHex()+",**]"; 
    	ScriptBuilder2 res = ScriptBuilder2.deserialize(serialScript);

    	assertEquals(1, res.signatureSize());
    	assertEquals(2, res.size());
    	assertEquals(serialScript, ScriptBuilder2.serialize(res));
    	
    	serialScript = "15 [sig,"+key.getPrivateKeyAsHex()+",1*]"; 
    	res = ScriptBuilder2.deserialize(serialScript);

    	assertEquals(1, res.signatureSize());
    	assertEquals(2, res.size());
    	assertEquals(serialScript, ScriptBuilder2.serialize(res));
    	
    	serialScript = "15 [sig,"+key.getPrivateKeyAsHex()+",*0]"; 
    	res = ScriptBuilder2.deserialize(serialScript);

    	assertEquals(1, res.signatureSize());
    	assertEquals(2, res.size());
    	assertEquals(serialScript, ScriptBuilder2.serialize(res));
    	
    	serialScript = "15 [sig,"+key.getPrivateKeyAsHex()+",10]"; 
    	res = ScriptBuilder2.deserialize(serialScript);

    	assertEquals(1, res.signatureSize());
    	assertEquals(2, res.size());
    	assertEquals(serialScript, ScriptBuilder2.serialize(res));
    	
    	serialScript = "15 [sig,"+key.getPrivateKeyAsHex()+",*1]"; 
    	res = ScriptBuilder2.deserialize(serialScript);

    	assertEquals(1, res.signatureSize());
    	assertEquals(2, res.size());
    	assertEquals(serialScript, ScriptBuilder2.serialize(res));
    	
    	serialScript = "15 [sig,"+key.getPrivateKeyAsHex()+",11]"; 
    	res = ScriptBuilder2.deserialize(serialScript);

    	assertEquals(1, res.signatureSize());
    	assertEquals(2, res.size());
    	assertEquals(serialScript, ScriptBuilder2.serialize(res));
    }
}
