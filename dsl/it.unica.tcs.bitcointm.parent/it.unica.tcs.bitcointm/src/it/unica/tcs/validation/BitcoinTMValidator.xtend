/*
 * Copyright 2017 Nicola Atzei
 */

/*
 * generated by Xtext 2.11.0
 */
package it.unica.tcs.validation

import com.google.inject.Inject
import it.unica.tcs.bitcoinTM.AbsoluteTime
import it.unica.tcs.bitcoinTM.AfterTimeLock
import it.unica.tcs.bitcoinTM.BitcoinTMFactory
import it.unica.tcs.bitcoinTM.BitcoinTMPackage
import it.unica.tcs.bitcoinTM.BitcoinValue
import it.unica.tcs.bitcoinTM.Declaration
import it.unica.tcs.bitcoinTM.DeclarationLeft
import it.unica.tcs.bitcoinTM.DeclarationReference
import it.unica.tcs.bitcoinTM.ExpressionI
import it.unica.tcs.bitcoinTM.Import
import it.unica.tcs.bitcoinTM.Input
import it.unica.tcs.bitcoinTM.KeyLiteral
import it.unica.tcs.bitcoinTM.Literal
import it.unica.tcs.bitcoinTM.Modifier
import it.unica.tcs.bitcoinTM.Output
import it.unica.tcs.bitcoinTM.PackageDeclaration
import it.unica.tcs.bitcoinTM.Participant
import it.unica.tcs.bitcoinTM.ProcessDeclaration
import it.unica.tcs.bitcoinTM.ProcessReference
import it.unica.tcs.bitcoinTM.RelativeTime
import it.unica.tcs.bitcoinTM.ScriptArithmeticSigned
import it.unica.tcs.bitcoinTM.ScriptDiv
import it.unica.tcs.bitcoinTM.ScriptTimes
import it.unica.tcs.bitcoinTM.Signature
import it.unica.tcs.bitcoinTM.SignatureType
import it.unica.tcs.bitcoinTM.TransactionBody
import it.unica.tcs.bitcoinTM.TransactionDeclaration
import it.unica.tcs.bitcoinTM.TransactionLiteral
import it.unica.tcs.bitcoinTM.Versig
import it.unica.tcs.compiler.TransactionCompiler
import it.unica.tcs.lib.Hash.Hash160
import it.unica.tcs.lib.Hash.Hash256
import it.unica.tcs.lib.Hash.Ripemd160
import it.unica.tcs.lib.Hash.Sha256
import it.unica.tcs.lib.utils.BitcoinUtils
import it.unica.tcs.utils.ASTUtils
import it.unica.tcs.xsemantics.BitcoinTMTypeSystem
import java.util.HashSet
import java.util.Set
import org.bitcoinj.core.AddressFormatException
import org.bitcoinj.core.DumpedPrivateKey
import org.bitcoinj.core.Transaction
import org.bitcoinj.core.Utils
import org.bitcoinj.core.VerificationException
import org.bitcoinj.core.WrongNetworkException
import org.bitcoinj.script.Script
import org.bitcoinj.script.ScriptException
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.naming.IQualifiedNameConverter
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.resource.IContainer
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtext.resource.IResourceDescription
import org.eclipse.xtext.resource.IResourceDescriptions
import org.eclipse.xtext.resource.impl.ResourceDescriptionsProvider
import org.eclipse.xtext.validation.Check
import org.eclipse.xtext.validation.CheckType
import org.eclipse.xtext.validation.ValidationMessageAcceptor

import static org.bitcoinj.script.Script.*

/**
 * This class contains custom validation rules. 
 *
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#validation
 */
class BitcoinTMValidator extends AbstractBitcoinTMValidator {

//	private static Logger logger = Logger.getLogger(BitcoinTMValidator);

	@Inject private extension IQualifiedNameConverter
    @Inject private extension BitcoinTMTypeSystem
    @Inject private extension ASTUtils    
    @Inject private extension TransactionCompiler
    @Inject	private ResourceDescriptionsProvider resourceDescriptionsProvider;
	@Inject	private IContainer.Manager containerManager;
//	@Inject private KeyStore keyStore
	
	/*
	 * INFO
	 */	
//	@Check
//	def void checkSingleElementArray(TransactionBody tbody) {
//		
////		logger.trace("--- TRACE TEST --- ")
////		logger.info ("--- INFO  TEST --- ")
////		logger.warn ("--- WARN  TEST --- ")
////		logger.error("--- ERROR TEST --- ")
////		logger.fatal("--- FATAL TEST --- ")
//		
//		var inputs = tbody.inputs
//		var outputs = tbody.outputs
//		
//		if (tbody.isMultiIn && inputs.size==1) {
//			info("Single element arrays can be replaced by the element itself.",
//				BitcoinTMPackage.Literals.TRANSACTION_BODY__INPUTS
//			);	
//		}
//		
//		if (tbody.isIsMultiOut && outputs.size==1) {
//			info("Single element arrays can be replaced by the element itself.", 
//				BitcoinTMPackage.Literals.TRANSACTION_BODY__OUTPUTS
//			);	
//		}
//	}

	/*
	 * WARNING
	 */
	
	@Check
	def void checkUnusedParameters(DeclarationLeft param){

		if (!(param.eContainer instanceof Script))
			return;
		
		var references = EcoreUtil.UsageCrossReferencer.find(param, param.eResource());
		// var references = EcoreUtil2.getAllContentsOfType(script.exp, VariableReference).filter[v|v.ref==p].size 
		if (references.size==0)
			warning("Unused variable '"+param.name+"'.", 
				param,
				BitcoinTMPackage.Literals.DECLARATION_LEFT__NAME
			);			
	}

	@Check
	def void checkVerSigDuplicatedKeys(Versig versig) {
		
		for(var i=0; i<versig.pubkeys.size-1; i++) {
			for(var j=i+1; j<versig.pubkeys.size; j++) {
				
				var k1 = versig.pubkeys.get(i)
				var k2 = versig.pubkeys.get(j)
				
				if (k1==k2) {
					warning("Duplicated public key.", versig, BitcoinTMPackage.Literals.VERSIG__PUBKEYS, i);
					warning("Duplicated public key.", versig,BitcoinTMPackage.Literals.VERSIG__PUBKEYS, j);
				}
			}
		}		
	}
	
	@Check
	def void checkSignatureModifiers(Signature signature) {
		
		var input = EcoreUtil2.getContainerOfType(signature, Input);
		for (other: EcoreUtil2.getAllContentsOfType(input, Signature)){
			
			if (signature!=other && signature.modifier.restrictedBy(other.modifier)) {
				warning('''This signature modifier is nullified by another one.''',
					signature,
					BitcoinTMPackage.Literals.SIGNATURE__MODIFIER
				);
				warning('''This signature modifier is nullifying another one.''',
					other, 
					BitcoinTMPackage.Literals.SIGNATURE__MODIFIER
				);
			}
		}	
	}
	
	def private boolean restrictedBy(Modifier _this, Modifier other) {
		false;
	}
	
	@Check
	def void checkEmptyLambda(it.unica.tcs.bitcoinTM.Script script) {
		if (script.params.size==0 && !script.isOpReturn) {
		    
		    if (script.eContainer instanceof Output)
    			warning("This output could be redeemed without providing any arguments.",
    				script.eContainer,
    				BitcoinTMPackage.Literals.OUTPUT__SCRIPT
    			);
    		
    		if (script.eContainer instanceof Input)
                warning("This output could be redeemed without providing any arguments.",
                    script.eContainer,
                    BitcoinTMPackage.Literals.INPUT__REDEEM_SCRIPT
                );
		}
	}
	
	
	@Check
	def void checkInterpretExp(ExpressionI exp) {
		
		if (context.containsKey(exp.eContainer) 
			|| exp instanceof Literal
			|| exp instanceof ScriptArithmeticSigned
			|| exp.eContainer instanceof BitcoinValue
		){
			// your parent can be simplified, so you are too
			context.put(exp, exp)
			return
		}
		
		if (exp instanceof DeclarationReference) {
			// references which refer to a declaration are interpreted as their right-part interpretation.
			// It's not useful to show that.
			return;
		}
		
		if (exp instanceof TransactionBody) {
			// It's not useful to show that.
			return;
		}
		
		var resInterpret = exp.interpret(newHashMap)		// simplify if possible, then interpret
		
		var container = exp.eContainer
		var index = 
			if (container instanceof Input) {
				container.exps.indexOf(exp)
			}
			else ValidationMessageAcceptor.INSIGNIFICANT_INDEX
		
		if (!resInterpret.failed /* || !resSimplify.failed*/) {
			
			// the expression can be simplified. Store it within the context such that sub-expression will skip this check
			context.put(exp, exp)
			
			val value = resInterpret.first
		
			var compilationResult = 
				switch (value) {
					Hash160: 	BitcoinTMFactory.eINSTANCE.createHash160Type.value+":"+BitcoinUtils.encode(value.bytes)
					Hash256: 	BitcoinTMFactory.eINSTANCE.createHash256Type.value+":"+BitcoinUtils.encode(value.bytes)
					Ripemd160: 	BitcoinTMFactory.eINSTANCE.createRipemd160Type.value+":"+BitcoinUtils.encode(value.bytes)
					Sha256: 	BitcoinTMFactory.eINSTANCE.createSha256Type.value+":"+BitcoinUtils.encode(value.bytes)
					String: 	'"'+value+'"' 
					default: 	value.toString
				} 
		
			info('''This expression can be simplified. It will be compiled as «compilationResult» ''',
				exp.eContainer,
				exp.eContainmentFeature,
				index
			);
			
		}
	}

	
	
	/*
     * ERROR
     */
	
	@Check
	def void checkPackageDuplicate(PackageDeclaration pkg) {
		var Set<QualifiedName> names = new HashSet();
		var IResourceDescriptions resourceDescriptions = resourceDescriptionsProvider.getResourceDescriptions(pkg.eResource());
		var IResourceDescription resourceDescription = resourceDescriptions.getResourceDescription(pkg.eResource().getURI());
		for (IContainer c : containerManager.getVisibleContainers(resourceDescription, resourceDescriptions)) {
			for (IEObjectDescription od : c.getExportedObjectsByType(BitcoinTMPackage.Literals.PACKAGE_DECLARATION)) {
				if (!names.add(od.getQualifiedName())) {
					error(
						"Duplicated package name", 
						BitcoinTMPackage.Literals.PACKAGE_DECLARATION__NAME
					);
				}
			}
		}
	}
	
	@Check
	def void checkImport(Import imp) {
		
		var packageName = (imp.eContainer as PackageDeclaration).name.toQualifiedName
		var importedPackage = imp.importedNamespace.toQualifiedName
		
		if (packageName.equals(importedPackage.skipLast(1))) {
			error(
				'''The import «importedPackage» refers to this package declaration''', 
				BitcoinTMPackage.Literals.IMPORT__IMPORTED_NAMESPACE
			);
			return
		}
		
		var Set<QualifiedName> names = new HashSet();
		var IResourceDescriptions resourceDescriptions = resourceDescriptionsProvider.getResourceDescriptions(imp.eResource());
		var IResourceDescription resourceDescription = resourceDescriptions.getResourceDescription(imp.eResource().getURI());
		
		for (IContainer c : containerManager.getVisibleContainers(resourceDescription, resourceDescriptions)) {
			for (IEObjectDescription od : c.getExportedObjectsByType(BitcoinTMPackage.Literals.PACKAGE_DECLARATION)) {
				names.add(od.qualifiedName.append("*"))
			}
			for (IEObjectDescription od : c.getExportedObjectsByType(BitcoinTMPackage.Literals.TRANSACTION_DECLARATION)) {
				names.add(od.qualifiedName)
			}
		}
		
		if (!names.contains(importedPackage)) {
			error(
				'''The import «importedPackage» cannot be resolved''', 
				BitcoinTMPackage.Literals.IMPORT__IMPORTED_NAMESPACE
			);
		}
	}
	
//	@Check(NORMAL)
//	def void checkUserTransactionIsMined(TransactionDeclaration t) {
//		
//		try {
//			val txB = t.compileTransaction
//			if (txB.isReady) {
//				val txId = txB.toTransaction.hashAsString
//				
//				if (txId !== null) {
//					val isMined = bitcoinClient.isMined(txId)
//					
//					if (isMined)
//						info('''The transaction is already on the blockchain with id «txId»''', 
//							t,
//							BitcoinTMPackage.Literals.TRANSACTION_DECLARATION__NAME
//						);
//				}
//				
//			}
//		}
//		catch (CompileException e) {
//			info('''Compile error. Cannot check if the transaction is already mined.''', 
//				t,
//				BitcoinTMPackage.Literals.TRANSACTION_DECLARATION__NAME
//			);
//		}
//		catch (ConnectionError e) {
//			val model = EcoreUtil.getRootContainer(t);
//			warning('''Online checks are disabled. An error occurred communicating with the server.''', 
//				t,
//				BitcoinTMPackage.Literals.TRANSACTION_DECLARATION__NAME
//			);
//		}	
//		
//	}
//	
//	@Check
//	def void checkSerialTransactionIsMined(SerialTransactionDeclaration t) {
//		
//		val tx = bitcoinUtils.getTransactionByIdOrHex(if (t.bytes!==null) t.bytes else t.id, t.networkParams);
//		var txId = tx.hashAsString
//		val isMined = bitcoinClient.isMined(txId)
//		
//		if (!isMined)
//			info('''The transaction «txId» is not mined''', 
//				t,
//				BitcoinTMPackage.Literals.TRANSACTION_DECLARATION__NAME
//			);
//	}
	
	
	@Check
	def void checkTransactionDeclarationNameIsUnique(Declaration t) {
		
		if (t instanceof ProcessDeclaration)
			return
		
		var root = EcoreUtil2.getRootContainer(t);
		val allDeclarations = EcoreUtil2.getAllContentsOfType(root, Declaration)
		val allDeclarationsNoPart = allDeclarations.filter[d|!(d.eContainer instanceof Participant)]
		
		for (other: allDeclarationsNoPart){
			
			if (t!=other && t.left.name.equals(other.left.name)) {
				error("Duplicated name '"+other.left.name+"'.", 
					t.left,
					BitcoinTMPackage.Literals.DECLARATION_LEFT__NAME
				);
			}
		}
	}
	
    @Check
	def void checkProcessDeclarationNameIsUnique(ProcessDeclaration t) {
		
		var container = EcoreUtil2.getContainerOfType(t, Participant);
		
		for (other: EcoreUtil2.getAllContentsOfType(container, ProcessDeclaration)){	// within a participant
			
			if (t!=other && t.getName.equals(other.name)) {
				error("Duplicated name '"+other.name+"'.",
					t,
					BitcoinTMPackage.Literals.PROCESS_DECLARATION__NAME
				);
			}
		}
		
		for (other: EcoreUtil2.getAllContentsOfType(container, Declaration)){			// within a participant
			
			if (t!=other && t.getName.equals(other.left.name)) {
				error("Duplicated name '"+other.left.name+"'.",
					t,
					BitcoinTMPackage.Literals.DECLARATION_LEFT__NAME
				);
			}
		}
	}
	
	@Check
	def void checkVerSig(Versig versig) {
		
		if (versig.pubkeys.size>15) {
			error("Cannot verify more than 15 public keys.", 
				BitcoinTMPackage.Literals.VERSIG__PUBKEYS
			);
		}
		
		if (versig.signatures.size > versig.pubkeys.size) {
			error("The number of signatures cannot exceed the number of public keys.", 
				versig,
				BitcoinTMPackage.Literals.VERSIG__SIGNATURES
			);
		}
//		
//		for(var i=0; i<versig.pubkeys.size; i++) {
//			var k = versig.pubkeys.get(i)
//			
//			if ((k instanceof KeyDeclaration) && k.isPlaceholder) {
//				error("Cannot compute the public key.", 
//					versig,
//					BitcoinTMPackage.Literals.VERSIG__PUBKEYS,
//					i
//				);
//			}
//		}
	}
	
	@Check
	def void checkSign(Signature sig) {
		var k = sig.key
		
		if (k instanceof DeclarationReference) {
			if (k.ref.eContainer instanceof TransactionDeclaration)
				error("Cannot use parametric key.", 
					sig,
					BitcoinTMPackage.Literals.SIGNATURE__KEY
				);
		}
	}
	
	
	@Check
	def void checkKeyDeclaration(KeyLiteral k) {
		
		try {
			DumpedPrivateKey.fromBase58(k.networkParams, k.value)
		}
		catch (WrongNetworkException e) {
			error("Key is not valid for the given network.", 
				k,
				BitcoinTMPackage.Literals.KEY_LITERAL__VALUE
			)			
		}
		catch (AddressFormatException e) {
			error("Invalid key. "+e.message, 
				k,
				BitcoinTMPackage.Literals.KEY_LITERAL__VALUE
			)
		}
	}
	
//	@Check
//	def void checkKeyDeclaration(KeyL keyDecl) {
//		
//		var pvtKey = keyDecl.value;
//		
//		var pvtErr = false;
//		var ValidationResult validationResult;
//		
//		/*
//		 * WiF format: 	[1 byte version][32 bytes key][1 byte compression (optional)][4 bytes checksum] 
//		 * Length:		36 o 38 bytes (without/with compression)
//		 */
//		if (pvtKey!==null && pvtKey.length!=52) {
//			error("Invalid key length.", 
//				keyDecl,
//				BitcoinTMPackage.Literals.KEY_DECLARATION__VALUE
//			)
//			pvtErr = true
//		}
//		
//		/*
//		 * Check if the encoding is valid (like the checksum bytes)
//		 */
//		if (!pvtErr && pvtKey !== null && !(validationResult=pvtKey.isBase58WithChecksum).ok) {
//			error('''Invalid encoding of the private key. The string must represent a valid bitcon address in WiF format. Details: «validationResult.message»''',
//				keyDecl,
//				BitcoinTMPackage.Literals.KEY_DECLARATION__VALUE			)
//			pvtErr = true
//		}		
//		
//		/*
//		 * Check if the declarations reflect the network declaration
//		 */
//		if (!pvtErr && pvtKey !== null && !(validationResult=pvtKey.isValidPrivateKey(keyDecl.networkParams)).ok) {
//			error('''The address it is not compatible with the network declaration (default is testnet). Details: «validationResult.message»''',
//				keyDecl,
//				BitcoinTMPackage.Literals.KEY_DECLARATION__VALUE
//			)
//			pvtErr = true
//		}
//	}
	
	
	@Check
	def void checkUniqueLambdaParameters(it.unica.tcs.bitcoinTM.Script p) {
		
		for (var i=0; i<p.params.size-1; i++) {
			for (var j=i+1; j<p.params.size; j++) {
				if (p.params.get(i).name == p.params.get(j).name) {
					error(
						"Duplicate parameter name '"+p.params.get(j).name+"'.", 
						p.params.get(j),
						BitcoinTMPackage.Literals.DECLARATION_LEFT__NAME, j
					);
				}
			}
		}
	}
	
	@Check
	def void checkScriptWithoutMultply(it.unica.tcs.bitcoinTM.Script p) {
		
		val exp = p.exp.interpretSafe
		
		val times = EcoreUtil2.getAllContentsOfType(exp, ScriptTimes);
		val divs = EcoreUtil2.getAllContentsOfType(exp, ScriptDiv);
		var signs = EcoreUtil2.getAllContentsOfType(exp, Signature);
		
		times.forEach[t|
			error(
				"Multiplications are not permitted within scripts.", 
				t.eContainer,
				t.eContainingFeature
			);
		]
		
		divs.forEach[d|
			error(
				"Divisions are not permitted within scripts.", 
				d.eContainer,
				d.eContainingFeature
			);
		]
			
		signs.forEach[s|
			error("Signatures are not allowed within output scripts.", 
				s.eContainer,
				s.eContainmentFeature
			);
		]
	}

	@Check
	def void checkSerialTransaction(TransactionLiteral tx) {
		
		try {
			val txJ = new Transaction(tx.networkParams, BitcoinUtils.decode(tx.value))
			txJ.verify
		} 
		catch (VerificationException e) {
			error(
				'''Transaction is invalid. Details: «e.message»''',
				tx,
				null
			);				
		}
	}
	
	@Check(CheckType.NORMAL)
	def void checkUserDefinedTx(TransactionDeclaration tx) {

		val tbody = tx.right.value as TransactionBody
		var hasError = false;
		
		/*
		 * Check transaction parameters
		 */
		for (param: tx.left.params) {
			if (param.type instanceof SignatureType) {
				error(
                    "Signature parameters are not allowed yet.",
                    param,
                    BitcoinTMPackage.Literals.DECLARATION_LEFT__NAME
                );
			    hasError = hasError || true
			}
		}
		
		
		if(hasError) return;  // interrupt the check
		
		/*
		 * Verify that inputs are valid
		 */
		
		for (input: tbody.inputs) {
			var valid = 
				input.isPlaceholder || (
//					input.checkInputTransactionParams && 
					input.checkInputIndex && 
					input.checkInputExpressions
				)
				
		    hasError = hasError || !valid
		}
		
		if(hasError) return;  // interrupt the check
		
		/*
		 * pairwise verify that inputs are unique
		 */
//		for (var i=0; i<tbody.inputs.size-1; i++) {
//			for (var j=i+1; j<tbody.inputs.size; j++) {
//				
//				var inputA = tbody.inputs.get(i)
//				var inputB = tbody.inputs.get(j)
//				
//				// these checks need to be executed in this order
//				var areValid = checkInputsAreUnique(inputA, inputB)
//				
//				hasError = hasError || !areValid
//			}
//		}
//		
//		if(hasError) return;  // interrupt the check

		/*
		 * Verify that the fees are positive
		 */
        hasError = !(tx.right.value as TransactionBody).checkFee
        
        if(hasError) return;  // interrupt the check
        
        /*
         * Verify that the input correctly spends the output
         */
        hasError = tx.correctlySpendsOutput
	}

	
	def boolean checkInputIndex(Input input) {

        var outIndex = input.outpoint
        var int numOfOutputs
        var inputTx = input.txRef
        
        if (inputTx instanceof TransactionLiteral) {
			numOfOutputs = new Transaction(input.networkParams, BitcoinUtils.decode(inputTx.value)).outputs.size
        }
        else if (inputTx instanceof DeclarationReference) {
	        if (inputTx.ref.isTx){
	        	val tx = inputTx.ref.txDeclaration
	            numOfOutputs = (tx.right.value as TransactionBody).outputs.size
	        }
	        else if (inputTx.ref.isTxLiteral){
	        	val tx = inputTx.ref.getTxLiteral.value
	            numOfOutputs = new Transaction(input.networkParams, BitcoinUtils.decode(tx)).outputs.size
	        }
	        else if (inputTx.ref.isTxParameter) {
	        	return true
	        }
        }
        else 
        	throw new IllegalStateException('''Unexpected class «inputTx»''')
        
        if (outIndex>=numOfOutputs) {
            error("This input is pointing to an undefined output script.",
                input,
                BitcoinTMPackage.Literals.INPUT__TX_REF
            );
            return false
        }
        
        return true
    }
    
    def boolean checkInputExpressions(Input input) {

        var outputIdx = input.outpoint
		var inputTx = input.txRef
        
        switch(inputTx) {	
        	TransactionLiteral: {
        		
        		val refTx = new Transaction(input.networkParams, BitcoinUtils.decode(inputTx.value))
        		
        		if (refTx.getOutput(outputIdx).scriptPubKey.payToScriptHash) {
	            	input.failIfRedeemScriptIsMissing
	            }
	            else {
	            	input.failIfRedeemScriptIsDefined
	            }
        	}

        	DeclarationReference: {
				val refTx = inputTx.ref.eContainer
				
				if (refTx instanceof TransactionDeclaration) {
		            var outputScript = (refTx.right.value as TransactionBody).outputs.get(new Long(outputIdx).intValue).script;
		            
		            var numOfExps = input.exps.size
		            var numOfParams = outputScript.params.size
		            
		            if (numOfExps!=numOfParams) {
		                error(
		                    "The number of inputs does not match the number of parameters expected by the output script.",
		                    input,
		                    BitcoinTMPackage.Literals.INPUT__EXPS
		                );
		                return false
		            }
		            input.failIfRedeemScriptIsDefined
		           
		            return true
		        }
		        else if (
		        	refTx instanceof Declaration &&
		        	(refTx as Declaration).right.value instanceof TransactionLiteral
		        ) {
		      		
		      		val tx = (refTx as Declaration).right.value as TransactionLiteral
		      		val txJ = new Transaction(input.networkParams, BitcoinUtils.decode(tx.value))
        		
	        		if (txJ.getOutput(outputIdx).scriptPubKey.payToScriptHash) {
		            	input.failIfRedeemScriptIsMissing
		            }
		            else {
		            	input.failIfRedeemScriptIsDefined
		            }
			        	
		        }
        	}
        }
        
        return true
    }
    
    
    def boolean failIfRedeemScriptIsMissing(Input input) {
    	if (input.redeemScript===null) {
    		error(
                "You must specify the redeem script when referring to a P2SH output of a serialized transaction.",
                input,
                BitcoinTMPackage.Literals.INPUT__EXPS,
                input.exps.size-1
            );
            return false	
    	}
    	else {
    		// free variables are not allowed
    		var ok = true
    		for (v : EcoreUtil2.getAllContentsOfType(input.redeemScript, DeclarationReference)) {
    			if (v.ref.eContainer instanceof TransactionDeclaration) {
    				error(
	                    "Cannot reference transaction parameters from the redeem script.",
	                    v,
	                    BitcoinTMPackage.Literals.DECLARATION_REFERENCE__REF
	                );
	                ok = false;
    			}
    		}    		
	    	return ok
    	}
    }
    
    def boolean failIfRedeemScriptIsDefined(Input input) {
    	if (input.redeemScript!==null) {
            error(
                "You must not specify the redeem script when referring to a user-defined transaction.",
                input.redeemScript,
                BitcoinTMPackage.Literals.INPUT__EXPS,
                input.exps.size-1
            );
            return false
        }
        return true;
    }
    
//    def boolean checkInputsAreUnique(Input inputA, Input inputB) {
//        if (inputA.txRef.ref==inputB.txRef.ref && 
//            inputA.outpoint==inputB.outpoint
//        ) {
//            error(
//                "You cannot redeem the output twice.",
//                inputA,
//                BitcoinTMPackage.Literals.INPUT__TX_REF
//            );
//        
//            error(
//                "You cannot redeem the output twice.",
//                inputB,
//                BitcoinTMPackage.Literals.INPUT__TX_REF
//            );
//            return false
//        }
//        return true
//    }
	
    def boolean checkFee(TransactionBody tx) {
        
        if (tx.isCoinbase)
        	return true;
        
        var amount = 0L
        
        for (in : tx.inputs) {
        	var inputTx = in.txRef
        	
        	switch(inputTx) {	
	        	TransactionLiteral: {
	        		var index = in.outpoint.intValue
	                var txbody = inputTx.value
	                var value = txbody.getOutputAmount(tx.networkParams, index)
	                amount+=value
	        	}
	
	        	DeclarationReference: {
					val refTx = inputTx.ref.eContainer
					
					if (refTx instanceof TransactionDeclaration) {
						
		                var index = in.outpoint.intValue
		                var output = (refTx.right.value as TransactionBody).outputs.get(index) 
		                var value = output.value.exp.interpret(newHashMap).first as Long
		                amount+=value
			        }
			        else if (
			        	refTx instanceof Declaration &&
			        	(refTx as Declaration).right.value instanceof TransactionLiteral
			        ) {
			      		var index = in.outpoint.intValue
			        	val txbody = ((refTx as Declaration).right.value as TransactionLiteral).value
		                var value = txbody.getOutputAmount(tx.networkParams, index)
		                amount+=value
			        }
	        	}
	        }
        }
        
        for (output : tx.outputs) {
            var value = output.value.exp.interpret(newHashMap).first as Long
            amount-=value
        }

//        if (amount==0) {
//            warning("Fees are zero.",
//                tx,
//                BitcoinTMPackage.Literals.TRANSACTION_BODY__OUTPUTS
//            );
//        }
        
        if (amount<0) {
            error("The transaction spends more than expected.",
                tx,
                BitcoinTMPackage.Literals.TRANSACTION_BODY__OUTPUTS
            );
            return false;
        }
        
        return true;
    }
    
    def boolean correctlySpendsOutput(TransactionDeclaration tx) {
        
		var txBuilder = tx.compileTransaction
		val tbody = tx.right.value as TransactionBody
		
		if (!txBuilder.isReady) {
        	info(
				'''Cannot check if these inputs are correctly spending their outputs''',
				tx.right.value,
				BitcoinTMPackage.Literals.TRANSACTION_BODY__INPUTS						
			)
			return true
        }

		if (txBuilder.isCoinbase) {
			return true
		}

        for (var i=0; i<tbody.inputs.size; i++) {

			println('''correctlySpendsOutput: «tx.left.name».in[«i»]''');
			println(txBuilder.toString)
			
            var Script inScript = null
            var Script outScript = null
            
            if (txBuilder.isReady) {
				            	
	            try {
					// compile the transaction to BitcoinJ representation
					var txJ = txBuilder.toTransaction()

					println()					
					println(txJ.toString)
					
	                inScript = txJ.getInput(i).scriptSig
	                outScript = txJ.getInput(i).outpoint.connectedOutput.scriptPubKey
	                inScript.correctlySpends(
		                    txJ, 
		                    i, 
		                    outScript, 
		                    ALL_VERIFY_FLAGS
		                )
	            } catch(ScriptException e) {
	
	                warning(
	                    '''
	                    This input does not redeem the specified output script. 
	                    
	                    Details: «e.message»
	                    
	                    INPUT:   «inScript»
	                    OUTPUT:  «outScript»
	                    «IF outScript.isPayToScriptHash»
	                    REDEEM SCRIPT:  «new Script(inScript.chunks.get(inScript.chunks.size-1).data)»
	                    REDEEM SCRIPT HASH:  «BitcoinUtils.encode(Utils.sha256hash160(new Script(inScript.chunks.get(inScript.chunks.size-1).data).program))»
						«ENDIF»
						''',
	                    tbody,
	                    BitcoinTMPackage.Literals.TRANSACTION_BODY__INPUTS, 
	                    i
	                );
	            } catch(Exception e) {
	                error('''Something went wrong: see error for details''',
							tbody.eContainer,
							tbody.eContainingFeature)
					e.printStackTrace
	            }
            }
            else {
            	info('''Cannot check if these inputs are correctly spending their outputs.''',
					tbody,
					BitcoinTMPackage.Literals.TRANSACTION_BODY__INPUTS,
					i	
				)
            }
        }
        return true
    }
    
    @Check
    def void checkPositiveOutValue(Output output) {
    	
    	var value = output.value.exp.interpret(newHashMap).first as Long
    	var script = output.script
    	
    	if (script.isOpReturn && value>0) {
    		error("OP_RETURN output scripts must have 0 value.",
                output,
                BitcoinTMPackage.Literals.OUTPUT__VALUE
            );
    	}
    	
    	// https://github.com/bitcoin/bitcoin/commit/6a4c196dd64da2fd33dc7ae77a8cdd3e4cf0eff1
    	if (!script.isOpReturn && value<546) {
    		error("Output (except OP_RETURN scripts) must spend at least 546 satoshis.",
                output,
                BitcoinTMPackage.Literals.OUTPUT__VALUE
            );
    	}
    }
    
    /*
     * https://en.bitcoin.it/wiki/Script
     * "Currently it is usually considered non-standard (though valid) for a transaction to have more than one OP_RETURN output or an OP_RETURN output with more than one pushdata op. "
     */
    @Check
    def void checkJustOneOpReturn(TransactionDeclaration tx) {
    	val tbody = tx.right.value as TransactionBody
		
    	var boolean[] error = newBooleanArrayOfSize(tbody.outputs.size);
    	    	
		for (var i=0; i<tbody.outputs.size-1; i++) {
			for (var j=i+1; j<tbody.outputs.size; j++) {
				
				var outputA = tbody.outputs.get(i)
				var outputB = tbody.outputs.get(j)
				
				// these checks need to be executed in this order
				if (outputA.script.isOpReturn && outputB.script.isOpReturn
		        ) {
					if (!error.get(i) && (error.set(i,true) && true))
			            error(
			                "You cannot define more than one OP_RETURN script per transaction.",
			                outputA.eContainer,
			                outputA.eContainingFeature,
			                i
			            );
		        
		            if (!error.get(j) && (error.set(j,true) && true))
				        error(
			                "You cannot define more than one OP_RETURN script per transaction.",
			                outputB.eContainer,
			                outputB.eContainingFeature,
			                j
			            );
		        }
			}
		}
    }
    
    @Check
    def void checkAbsoluteTime(AbsoluteTime tlock) {
    	
    	if (tlock.value<0) {
			error(
                "Negative timelock is not permitted.",
                tlock,
                BitcoinTMPackage.Literals.TIME__VALUE
            );
    	}
    	
    	if (tlock.isBlock && tlock.value>=Transaction.LOCKTIME_THRESHOLD) {
			error(
                "Block number must be lower than 500_000_000.",
                tlock,
                BitcoinTMPackage.Literals.TIME__VALUE
            );
    	}
    	
    	if (!tlock.isBlock && tlock.value<Transaction.LOCKTIME_THRESHOLD) {
    		error(
                "Block number must be greater or equal than 500_000_000 (1985-11-05 00:53:20). Found "+tlock.value,
                tlock,
                BitcoinTMPackage.Literals.TIME__VALUE
            );
    	}
    }
    
    @Check
    def void checkRelativeTime(RelativeTime tlock) {
    	
    	
    }
    
    @Check
    def void checkAfter(AfterTimeLock after) {
    	
    	// transaction containing after
    	val tx = EcoreUtil2.getContainerOfType(after, TransactionDeclaration);
    	
    	// all the txs pointing to tx
    	var txReferences = EcoreUtil2.getAllContentsOfType(EcoreUtil2.getRootContainer(after), DeclarationReference).filter[v|v.ref==tx]
    	
    	// all these txs have to define the timelock
    	for (ref : txReferences) {
    		
    		val body = EcoreUtil2.getContainerOfType(ref, TransactionBody);
    		
    		// the transaction does not define a timelock
    		if (body.tlock===null) {
    			error(
	                '''Referred output requires to define a timelock.''',
	                ref.eContainer,			// INPUT
	                ref.eContainingFeature	// INPUT__TX_REF
	            );
    		}
			// transaction lock is defined
    		else {	
	    	
				// after expression uses an absolute time     	
	    		if (after.timelock.isAbsolute)  {
	    			
	        		var absTimes = body.tlock.times.filter(AbsoluteTime).map(x|x as AbsoluteTime) 

			        if(absTimes.size==0){
	 					error(
			                '''Transaction does not define an absolute timelock''',
			                body,
			                BitcoinTMPackage.Literals.TRANSACTION_BODY__TLOCK
			            );
			        }
			        else if(absTimes.size==1) {
			        	// check if they are of the same type (block|date)
			        	if (after.timelock.isBlock && !absTimes.get(0).isBlock
							|| after.timelock.isRelative && !absTimes.get(0).isRelative
						)
							error(
				                '''Transaction timelock must be of type «IF after.timelock.isBlock»block«ELSE»timestamp«ENDIF».''',
				                absTimes.get(0).eContainer,
				                absTimes.get(0).eContainingFeature
				            );
			        }
			        else {
			        	for (t : absTimes)
							error(
				                '''Only one absolute timelock is allowed''',
				                t.eContainer,
				                t.eContainingFeature
				            );
			        }
	    		}
	    		
	    		// after expression uses a relative time
	    		if (after.timelock.isRelative) {
	    			
		    		var timesPerTx = body.tlock.times
			    		.filter(RelativeTime)
			    		.filter(x | (x as RelativeTime).tx == tx)
			    		
			    	
			    	if (timesPerTx.size==0) {
			    		error(
			                '''Transaction does not define a relative timelock for transaction «ref.ref.name»''',
			                body,
			                BitcoinTMPackage.Literals.TRANSACTION_BODY__TLOCK
			            );
			    	}
			    	else if (timesPerTx.size==1) {
			    		// check if they are of the same type (block|date)
						if (after.timelock.isBlock && !timesPerTx.get(0).isBlock
							|| after.timelock.isRelative && !timesPerTx.get(0).isRelative
						)
							error(
				                '''Transaction timelock must be of type «IF after.timelock.isBlock»block«ELSE»timestamp«ENDIF».''',
				                timesPerTx.get(0).eContainer,
				                timesPerTx.get(0).eContainingFeature
				            );
			    	}
			    	else {
			    		for (t : timesPerTx)
				    		error(
				                '''Only one relative timelock is allowed per transaction''',
				                t.eContainer,
				                t.eContainingFeature
				            );
			    	}
	    		}
			} 
    	}
    }
    
	@Check
	def void checkProcessReference(ProcessReference pRef) {
        if (pRef.actualParams.size!=pRef.ref.params.size) {
            error(
                "The number of expressions does not match the number of parameters.",
                pRef,
                BitcoinTMPackage.Literals.PROCESS_REFERENCE__ACTUAL_PARAMS
            );
        }
	}
	
	
    
    
    
}