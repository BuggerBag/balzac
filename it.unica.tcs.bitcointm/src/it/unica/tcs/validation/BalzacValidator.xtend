/*
 * Copyright 2018 Nicola Atzei
 */

package it.unica.tcs.validation

import com.google.inject.Inject
import it.unica.tcs.balzac.AbsoluteTime
import it.unica.tcs.balzac.AddressLiteral
import it.unica.tcs.balzac.AfterTimeLock
import it.unica.tcs.balzac.BalzacPackage
import it.unica.tcs.balzac.BitcoinValue
import it.unica.tcs.balzac.Div
import it.unica.tcs.balzac.Import
import it.unica.tcs.balzac.Input
import it.unica.tcs.balzac.IsMinedCheck
import it.unica.tcs.balzac.KeyLiteral
import it.unica.tcs.balzac.Model
import it.unica.tcs.balzac.Modifier
import it.unica.tcs.balzac.Output
import it.unica.tcs.balzac.PackageDeclaration
import it.unica.tcs.balzac.Parameter
import it.unica.tcs.balzac.Reference
import it.unica.tcs.balzac.Referrable
import it.unica.tcs.balzac.RelativeTime
import it.unica.tcs.balzac.Signature
import it.unica.tcs.balzac.Times
import it.unica.tcs.balzac.Transaction
import it.unica.tcs.balzac.TransactionHexLiteral
import it.unica.tcs.balzac.TransactionIDLiteral
import it.unica.tcs.balzac.TransactionInputOperation
import it.unica.tcs.balzac.TransactionOutputOperation
import it.unica.tcs.balzac.Versig
import it.unica.tcs.lib.ITransactionBuilder
import it.unica.tcs.lib.SerialTransactionBuilder
import it.unica.tcs.lib.TransactionBuilder
import it.unica.tcs.lib.client.BitcoinClientException
import it.unica.tcs.lib.client.TransactionNotFoundException
import it.unica.tcs.lib.utils.BitcoinUtils
import it.unica.tcs.utils.ASTUtils
import it.unica.tcs.utils.BitcoinClientFactory
import it.unica.tcs.xsemantics.BalzacInterpreter
import it.unica.tcs.xsemantics.Rho
import it.unica.tcs.xsemantics.interpreter.PublicKey
import java.util.HashMap
import java.util.HashSet
import java.util.Map
import java.util.Set
import org.apache.log4j.Logger
import org.bitcoinj.core.Address
import org.bitcoinj.core.AddressFormatException
import org.bitcoinj.core.DumpedPrivateKey
import org.bitcoinj.core.Utils
import org.bitcoinj.core.VerificationException
import org.bitcoinj.params.MainNetParams
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

import static org.bitcoinj.script.Script.*

/**
 * This class contains custom validation rules.
 *
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#validation
 */
class BalzacValidator extends AbstractBalzacValidator {

    static Logger logger = Logger.getLogger(BalzacValidator);

    @Inject extension IQualifiedNameConverter
    @Inject extension BalzacInterpreter
    @Inject extension ASTUtils
    @Inject ResourceDescriptionsProvider resourceDescriptionsProvider;
    @Inject IContainer.Manager containerManager;
    @Inject BitcoinClientFactory clientFactory;

    @Check
    def void checkUnusedParameters__Script(it.unica.tcs.balzac.Script script){

        for (param : script.params) {
            var references = EcoreUtil.UsageCrossReferencer.find(param, script.exp);
            if (references.size==0)
                warning("Unused variable '"+param.name+"'.",
                    param,
                    BalzacPackage.Literals.PARAMETER__NAME
                );
        }
    }

    @Check
    def void checkUnusedParameters__Transaction(Transaction tx){

        for (param : tx.params) {
            var references = EcoreUtil.UsageCrossReferencer.find(param, tx);
            if (references.size==0)
                warning("Unused variable '"+param.name+"'.",
                    param,
                    BalzacPackage.Literals.PARAMETER__NAME
                );
        }
    }

    @Check
    def void checkVerSigDuplicatedKeys(Versig versig) {

        for(var i=0; i<versig.pubkeys.size-1; i++) {
            for(var j=i+1; j<versig.pubkeys.size; j++) {

                var k1 = versig.pubkeys.get(i)
                var k2 = versig.pubkeys.get(j)

                if (k1==k2) {
                    warning("Duplicated public key.", versig, BalzacPackage.Literals.VERSIG__PUBKEYS, i);
                    warning("Duplicated public key.", versig,BalzacPackage.Literals.VERSIG__PUBKEYS, j);
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
                    BalzacPackage.Literals.SIGNATURE__MODIFIER
                );
                warning('''This signature modifier is nullifying another one.''',
                    other,
                    BalzacPackage.Literals.SIGNATURE__MODIFIER
                );
            }
        }
    }

    def private boolean restrictedBy(Modifier _this, Modifier other) {
        false;
    }

    @Check
    def void checkConstantScripts(it.unica.tcs.balzac.Script script) {

        val res = script.exp.interpretE

        if (!res.failed && (res.first instanceof Boolean)) {
            warning("Script will always evaluate to "+res.first,
                script.eContainer,
                script.eContainingFeature
            );
        }
    }

    @Check
    def void checkPackageDuplicate(PackageDeclaration pkg) {
        var Set<QualifiedName> names = new HashSet();
        var IResourceDescriptions resourceDescriptions = resourceDescriptionsProvider.getResourceDescriptions(pkg.eResource());
        var IResourceDescription resourceDescription = resourceDescriptions.getResourceDescription(pkg.eResource().getURI());
        for (IContainer c : containerManager.getVisibleContainers(resourceDescription, resourceDescriptions)) {
            for (IEObjectDescription od : c.getExportedObjectsByType(BalzacPackage.Literals.PACKAGE_DECLARATION)) {
                if (!names.add(od.getQualifiedName())) {
                    error(
                        "Duplicated package name",
                        BalzacPackage.Literals.PACKAGE_DECLARATION__NAME
                    );
                }
            }
        }
    }

    @Check
    def void checkImport(Import imp) {

        var packageName = (imp.eContainer as Model).package.name.toQualifiedName
        var importedPackage = imp.importedNamespace.toQualifiedName

        if (packageName.equals(importedPackage.skipLast(1))) {
            error(
                '''The import «importedPackage» refers to this package declaration''',
                BalzacPackage.Literals.IMPORT__IMPORTED_NAMESPACE
            );
            return
        }

        var Set<QualifiedName> names = new HashSet();
        var IResourceDescriptions resourceDescriptions = resourceDescriptionsProvider.getResourceDescriptions(imp.eResource());
        var IResourceDescription resourceDescription = resourceDescriptions.getResourceDescription(imp.eResource().getURI());

        for (IContainer c : containerManager.getVisibleContainers(resourceDescription, resourceDescriptions)) {
            for (IEObjectDescription od : c.getExportedObjectsByType(BalzacPackage.Literals.PACKAGE_DECLARATION)) {
                names.add(od.qualifiedName.append("*"))
            }
            for (IEObjectDescription od : c.getExportedObjectsByType(BalzacPackage.Literals.TRANSACTION)) {
                names.add(od.qualifiedName)
            }
        }

        if (!names.contains(importedPackage)) {
            error(
                '''The import «importedPackage» cannot be resolved''',
                BalzacPackage.Literals.IMPORT__IMPORTED_NAMESPACE
            );
        }
    }

    @Check
    def void checkDeclarationNameIsUnique(Referrable r) {

        if (r instanceof Parameter)
            return

        var root = EcoreUtil2.getRootContainer(r);
        val allReferrables = EcoreUtil2.getAllContentsOfType(root, Referrable).filter[x|!(x instanceof Parameter)]

        for (other: allReferrables){

            if (r!=other && r.name.equals(other.name)) {
                error("Duplicated name "+other.name,
                    r,
                    r.literalName
                );
            }
        }
    }

    @Check
    def void checkVerSig(Versig versig) {

        if (versig.pubkeys.size>15) {
            error("Cannot verify more than 15 public keys.",
                BalzacPackage.Literals.VERSIG__PUBKEYS
            );
        }

        if (versig.signatures.size > versig.pubkeys.size) {
            error("The number of signatures cannot exceed the number of public keys.",
                versig,
                BalzacPackage.Literals.VERSIG__SIGNATURES
            );
        }
    }

    @Check
    def void checkSigTransaction(Signature sig) {
        val isTxDefined = sig.isHasTx
        val isWithinInput = EcoreUtil2.getContainerOfType(sig, Input) !== null

        if (isTxDefined && isWithinInput) {
            error("You cannot specify the transaction to sign.",
                sig,
                BalzacPackage.Literals.SIGNATURE__TX
            );
            return
        }

        if (isTxDefined && sig.tx.isCoinbase) {
            error("Transaction cannot be a coinbase.",      // because you need a reference to the output script of the input i-th
                sig,
                BalzacPackage.Literals.SIGNATURE__TX
            );
            return
        }

        if (isTxDefined && sig.tx.isSerial) {
            error("Cannot sign a serialized transaction.",  // because you need a reference to the output script of the input i-th
                sig,
                BalzacPackage.Literals.SIGNATURE__TX
            );
            return
        }

        if (!isTxDefined && !isWithinInput) {
            error("You must specify the transaction to sign.",
                sig.eContainer,
                sig.eContainingFeature
            );
            return
        }

        val res = sig.tx.interpretE
        
        if (!res.failed) {
            val tx = res.first as ITransactionBuilder
            val inputSize = tx.inputs.size
            val outputSize = tx.outputs.size
            if (sig.inputIdx >= inputSize) {
                error('''Invalid input «sig.inputIdx». «IF inputSize == 1»0 expected (it can be omitted).«ELSE»Valid interval [0,«inputSize-1»].«ENDIF»''',
                    sig,
                    BalzacPackage.Literals.SIGNATURE__INPUT_IDX
                );
            }
            if (sig.modifier == Modifier.AISO || sig.modifier == Modifier.SISO) {
            	if (sig.inputIdx >= outputSize) {
	                error('''Invalid input «sig.inputIdx». Since you are signing a single output, the index must be «IF outputSize == 1»0 (it can be omitted).«ELSE» within [0,«outputSize-1»].«ENDIF»''',
	                    sig,
	                    BalzacPackage.Literals.SIGNATURE__INPUT_IDX
	                );
	            }
            }
        }
        else {
            error('''Error occurred evaluting transaction «sig.tx.nodeToString». Please report the error to the authors.''',
                sig,
                BalzacPackage.Literals.SIGNATURE__TX
            );
        }
    }


    @Check
    def void checkKeyDeclaration(KeyLiteral k) {
        val net = k.networkParams
        try {
            DumpedPrivateKey.fromBase58(net, k.value)
        }
        catch (AddressFormatException.WrongNetwork e) {
            error('''This key is not valid on the «IF net == MainNetParams.get()»mainnet«ELSE»testnet.«ENDIF»''',
                k,
                BalzacPackage.Literals.KEY_LITERAL__VALUE
            )
        }
        catch (AddressFormatException e) {
            error("Invalid key. "+e.message,
                k,
                BalzacPackage.Literals.KEY_LITERAL__VALUE
            )
        }
	}

    @Check
    def void checkAddressDeclaration(AddressLiteral k) {

        val net = k.networkParams
        try {
            Address.fromString(net, k.value)
        }
        catch (AddressFormatException.WrongNetwork e) {
            error('''This address is not valid on the «IF net == MainNetParams.get()»mainnet«ELSE»testnet.«ENDIF»''',
                k,
                BalzacPackage.Literals.ADDRESS_LITERAL__VALUE
            )
        }
        catch (AddressFormatException e) {
            error("Invalid address. "+e.message,
                k,
                BalzacPackage.Literals.ADDRESS_LITERAL__VALUE
            )
        }
    }

    @Check
    def void checkUniqueParameterNames__Script(it.unica.tcs.balzac.Script p) {

        for (var i=0; i<p.params.size-1; i++) {
            for (var j=i+1; j<p.params.size; j++) {
                if (p.params.get(i).name == p.params.get(j).name) {
                    error(
                        "Duplicated parameter name '"+p.params.get(j).name+"'.",
                        p.params.get(j),
                        BalzacPackage.Literals.PARAMETER__NAME, j
                    );
                }
            }
        }
    }

    @Check
    def void checkUniqueParameterNames__Transaction(Transaction p) {

        for (var i=0; i<p.params.size-1; i++) {
            for (var j=i+1; j<p.params.size; j++) {
                if (p.params.get(i).name == p.params.get(j).name) {
                    error(
                        "Duplicated parameter name '"+p.params.get(j).name+"'.",
                        p.params.get(j),
                        BalzacPackage.Literals.PARAMETER__NAME, j
                    );
                }
            }
        }
    }

    @Check
    def void checkScriptWithoutMultply(it.unica.tcs.balzac.Script p) {

        val exp = p.exp

        val times = EcoreUtil2.getAllContentsOfType(exp, Times);
        val divs = EcoreUtil2.getAllContentsOfType(exp, Div);
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
    def void checkSerialTransaction(TransactionHexLiteral tx) {

        try {
            val txJ = new org.bitcoinj.core.Transaction(tx.networkParams, BitcoinUtils.decode(tx.value))
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

    @Check
    def void checkSerialTransaction(TransactionIDLiteral tx) {

        try {
            val id = tx.value
            val client = clientFactory.getBitcoinClient(tx.networkParams)
            val hex = client.getRawTransaction(id)
            val txJ = new org.bitcoinj.core.Transaction(tx.networkParams, BitcoinUtils.decode(hex))
            txJ.verify
        }
        catch (TransactionNotFoundException e) {
            error(
                '''Transaction not found, please verify you have specified the correct network. Details: «e.message»''',
                tx,
                null
            );
        }
        catch (VerificationException e) {
            error(
                '''Transaction is invalid. Details: «e.message»''',
                tx,
                null
            );
        }
        catch (Exception e) {
            error(
                '''Unable to fetch the transaction from its ID. Check that trusted nodes are configured correctly''',
                tx,
                null
            );
            e.printStackTrace
        }
    }

    @Check(CheckType.NORMAL)
    def void checkUserDefinedTx(Transaction tx) {

        if (tx.isCoinbase)
            return;

        var hasError = false;

        /*
         * Verify that inputs are valid
         */
        val mapInputsTx = new HashMap<Input, ITransactionBuilder>
        for (input: tx.inputs) {
            /*
             * get the transaction input
             */
            val txInput = input.txRef

            if (txInput.txVariables.empty) {

                val res = input.txRef.interpretE

                if (res.failed) {
                    res.ruleFailedException.printStackTrace
                    error("Error evaluating the transaction input, see error log for details.",
                        input,
                        BalzacPackage.Literals.INPUT__TX_REF
                    );
                    hasError = hasError || true
                }
                else {
                    val txB = res.first as ITransactionBuilder
                    mapInputsTx.put(input, txB)
                    var valid =
                        input.isPlaceholder || (
                            input.checkInputIndex(txB) &&
                            input.checkInputExpressions(txB)
                        )

                    hasError = hasError || !valid
                }
            }
        }

        if(hasError) return;  // interrupt the check

        /*
         * pairwise verify that inputs are unique
         */
        for (var i=0; i<tx.inputs.size-1; i++) {
            for (var j=i+1; j<tx.inputs.size; j++) {

                var inputA = tx.inputs.get(i)
                var inputB = tx.inputs.get(j)

                var areValid = checkInputsAreUnique(inputA, inputB, mapInputsTx)

                hasError = hasError || !areValid
            }
        }

        if(hasError) return;  // interrupt the check

        /*
         * Verify that the fees are positive
         */
        hasError = !tx.checkFee

        if(hasError) return;  // interrupt the check

        /*
         * Verify that the input correctly spends the output
         */
        hasError = tx.correctlySpendsOutput
    }


    def boolean checkInputIndex(Input input, ITransactionBuilder inputTx) {

        var numOfOutputs = inputTx.outputs.size
        var outIndex = input.outpoint

        if (outIndex>=numOfOutputs) {
            error("This input is pointing to an undefined output script.",
                input,
                BalzacPackage.Literals.INPUT__TX_REF
            );
            return false
        }

        return true
    }

    def boolean checkInputExpressions(Input input, ITransactionBuilder inputTx) {

        var outputIdx = input.outpoint as int

        if (inputTx instanceof SerialTransactionBuilder) {
            if (inputTx.outputs.get(outputIdx).script.isP2SH) {
                input.failIfRedeemScriptIsMissing
            }
            else {
                input.failIfRedeemScriptIsDefined
            }
        }
        else if (inputTx instanceof TransactionBuilder) {
            input.failIfRedeemScriptIsDefined
        }

        if (inputTx.outputs.get(outputIdx).script.isP2PKH) {
            
            if (input.exps.size == 1) {
                if (!(input.exps.get(0) instanceof Signature)) {
                    error(
                        "Signature constructor expected, i.e. sig(k)",
                        input,
                        BalzacPackage.Literals.INPUT__EXPS,
                        0
                    )
                    return false
                }
            }
            else if (input.exps.size == 2) {
                val sig = input.exps.get(0).interpretE
                if (sig.failed || !(sig.first instanceof it.unica.tcs.xsemantics.interpreter.Signature)) {
                    error(
                        "Invalid expression type, signature is expected",
                        input,
                        BalzacPackage.Literals.INPUT__EXPS,
                        0
                    )
                    return false
                }
                val pubkey = input.exps.get(1).interpretE
                if (pubkey.failed || !(pubkey.first instanceof PublicKey)
                ) {
                    error(
                        "Invalid expression type, pubkey is expected",
                        input,
                        BalzacPackage.Literals.INPUT__EXPS,
                        1
                    )
                    return false
                }
            }
            else {
                error(
                    "Invalid number of expressions",
                    input,
                    null
                )
                return false
            }
            
            for (e : input.exps) {
            }
        }

        return true
    }


    def boolean failIfRedeemScriptIsMissing(Input input) {
        if (input.redeemScript===null) {
            error(
                "You must specify the redeem script when referring to a P2SH output of a serialized transaction.",
                input,
                BalzacPackage.Literals.INPUT__EXPS,
                input.exps.size-1
            );
            return false
        }
        else {
            // free variables are not allowed
            var ok = true
            for (v : EcoreUtil2.getAllContentsOfType(input.redeemScript, Reference)) {
                if (v.ref.eContainer instanceof org.bitcoinj.core.Transaction) {
                    error(
                        "Cannot reference transaction parameters from the redeem script.",
                        v,
                        BalzacPackage.Literals.REFERENCE__REF
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
                BalzacPackage.Literals.INPUT__EXPS,
                input.exps.size-1
            );
            return false
        }
        return true;
    }

    def boolean checkInputsAreUnique(Input inputA, Input inputB, Map<Input, ITransactionBuilder> mapInputsTx) {

        val txA = mapInputsTx.get(inputA)
        val txB = mapInputsTx.get(inputB)

        if (txA===null || txB===null)
            return true

        if (!txA.ready || !txB.ready)
            return true

        if (txA.toTransaction(inputA.ECKeyStore)==txB.toTransaction(inputB.ECKeyStore) && inputA.outpoint==inputB.outpoint
        ) {
            error(
                "Double spending. You cannot redeem the output twice.",
                inputA,
                BalzacPackage.Literals.INPUT__TX_REF
            );

            error(
                "Double spending. You cannot redeem the output twice.",
                inputB,
                BalzacPackage.Literals.INPUT__TX_REF
            );
            return false
        }
        return true
    }

    def boolean checkFee(Transaction _tx) {

        if (_tx.isCoinbase)
            return true;

        val res = _tx.interpretE

        if (!res.failed) {
            val tx = res.first as ITransactionBuilder

            var amount = 0L

            for (in : tx.inputs) {
                amount += in.parentTx.outputs.get(in.outIndex).value
            }

            for (output : tx.outputs) {
                amount-=output.value
            }

            if (amount<0) {
                error("The transaction spends more than expected.",
                    _tx,
                    BalzacPackage.Literals.TRANSACTION__OUTPUTS
                );
                return false;
            }

        }

        return true;
    }

    def boolean correctlySpendsOutput(Transaction tx) {

        /*
         * Check if tx has parameters and they are used
         */
        val hasUsedParameters = tx.params.exists[p|
            EcoreUtil.UsageCrossReferencer.find(p, tx).size > 0;
        ]

        if (hasUsedParameters) {
            return true
        }

        logger.info("witness check: interpreting "+astUtils.nodeToString(tx).replaceAll("\n"," \\ "))
        var res = tx.interpretE

        if (!res.failed) {
            var txBuilder = res.first as ITransactionBuilder

            if (txBuilder.isCoinbase) {
                return true
            }

            for (var i=0; i<tx.inputs.size; i++) {
                logger.info('''witness check: «tx.inputs.get(i).nodeToString.replaceAll("\n"," \\ ")»''')

                var Script inScript = null
                var Script outScript = null

                try {
                    // compile the transaction to BitcoinJ representation
                    var txJ = txBuilder.toTransaction(tx.ECKeyStore)

                    inScript = txJ.getInput(i).scriptSig
                    outScript = txJ.getInput(i).outpoint.connectedOutput.scriptPubKey
//                    val value = txJ.getInput(i).outpoint.connectedOutput.value

                    inScript.correctlySpends(
                            txJ,
                            i,
                            outScript,
//                            value,
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
                        tx,
                        BalzacPackage.Literals.TRANSACTION__INPUTS,
                        i
                    );
                } catch(Exception e) {
                    error('''Something went wrong: see error for details''',
                            tx,
                            BalzacPackage.Literals.TRANSACTION__INPUTS,
                            i)
                    e.printStackTrace
                }
            }
        }
        else {
            res.ruleFailedException.printStackTrace
            error(
                '''Error evaluating the transaction «tx.name», see error log for details.''',
                tx,
                BalzacPackage.Literals.TRANSACTION__INPUTS
            )

        }

        return true
    }

    @Check
    def void checkPositiveOutValue(Output output) {

        var value = output.value.exp.interpretE.first as Long
        var script = output.script as it.unica.tcs.balzac.Script

        if (script.isOpReturn(new Rho) && value>0) {
            error("OP_RETURN output scripts must have 0 value.",
                output,
                BalzacPackage.Literals.OUTPUT__VALUE
            );
        }

        // https://github.com/bitcoin/bitcoin/commit/6a4c196dd64da2fd33dc7ae77a8cdd3e4cf0eff1
        if (!script.isOpReturn(new Rho) && value<546) {
            error("Output (except OP_RETURN scripts) must spend at least 546 satoshis.",
                output,
                BalzacPackage.Literals.OUTPUT__VALUE
            );
        }
    }

    @Check
    def void checkJustOneOpReturn(Transaction tx) {
        /*
         * https://en.bitcoin.it/wiki/Script
         * "Currently it is usually considered non-standard (though valid) for a transaction to have more than one OP_RETURN output or an OP_RETURN output with more than one pushdata op."
         */

        var boolean[] error = newBooleanArrayOfSize(tx.outputs.size);

        for (var i=0; i<tx.outputs.size-1; i++) {
            for (var j=i+1; j<tx.outputs.size; j++) {

                var outputA = tx.outputs.get(i)
                var outputB = tx.outputs.get(j)

                // these checks need to be executed in this order
                if ((outputA.script as it.unica.tcs.balzac.Script).isOpReturn(new Rho) && (outputB.script as it.unica.tcs.balzac.Script).isOpReturn(new Rho)
                ) {
                    if (!error.get(i) && (error.set(i,true) && true))
                        warning(
                            "Currently it is usually considered non-standard (though valid) for a transaction to have more than one OP_RETURN output or an OP_RETURN output with more than one pushdata op.",
                            outputA.eContainer,
                            outputA.eContainingFeature,
                            i
                        );

                    if (!error.get(j) && (error.set(j,true) && true))
                        warning(
                            "Currently it is usually considered non-standard (though valid) for a transaction to have more than one OP_RETURN output or an OP_RETURN output with more than one pushdata op.",
                            outputB.eContainer,
                            outputB.eContainingFeature,
                            j
                        );
                }
            }
        }
    }

    @Check
    def void checkUniqueAbsoluteTimelock(AbsoluteTime tlock) {

        val isScriptTimelock = EcoreUtil2.getContainerOfType(tlock, it.unica.tcs.balzac.Script) !== null;

        if (isScriptTimelock)
            return

        var tx = EcoreUtil2.getContainerOfType(tlock, Transaction);
        for (other: tx.timelocks){

            if (tlock!=other && tlock.class==other.class) {
                error(
                	"Duplicated absolute timelock",
                    tlock,
                    null
                );
            }
        }
    }

    @Check
    def void checkUniqueRelativeTimelock(RelativeTime tlock) {

        val isScriptTimelock = EcoreUtil2.getContainerOfType(tlock, it.unica.tcs.balzac.Script) !== null;

        if (isScriptTimelock)
            return

        var tx = EcoreUtil2.getContainerOfType(tlock, Transaction);
        for (other: tx.timelocks){

            if (tlock!=other && tlock.class==other.class) {
                val tx1 = tlock.tx.interpretE.first
                val tx2 = (other as RelativeTime).tx.interpretE.first

                if (tx1==tx2)
                    error(
                    	"Duplicated relative timelock",
                        tlock,
                        null
                    );
            }
        }
    }

    @Check
    def void checkRelativeTimelockFromTx(RelativeTime tlock) {

        if (EcoreUtil2.getContainerOfType(tlock, AfterTimeLock) === null && tlock.tx === null) {
            error(
                'Missing reference to an input transaction',
                tlock,
                BalzacPackage.Literals.RELATIVE_TIME__TX
            );
        }
    }

    @Check
    def void checkRelativeTimelockFromTxIsInput(RelativeTime tlock) {

        if (tlock.tx !== null) {
            val tx = tlock.tx.interpretE.first
            val containingTx = EcoreUtil2.getContainerOfType(tlock, Transaction);

            for (in : containingTx.inputs) {
                val inTx = in.txRef.interpretE.first
                if (tx==inTx) {
                    return
                }
            }

            error(
                'Relative timelocks must refer to an input transaction',
                tlock,
                BalzacPackage.Literals.RELATIVE_TIME__TX
            );
        }
    }

    @Check
    def void checkAbsoluteTime(AbsoluteTime tlock) {

        val res = tlock.value.interpretE

        if (res.failed)
            return;

        val value = res.first as Long

        if (value<0) {
            error(
                "Negative timelock is not permitted.",
                tlock,
                BalzacPackage.Literals.TIMELOCK__VALUE
            );
        }

        if (tlock.isBlock && value>=org.bitcoinj.core.Transaction.LOCKTIME_THRESHOLD) {
            error(
                "Block number must be lower than 500_000_000.",
                tlock,
                BalzacPackage.Literals.TIMELOCK__VALUE
            );
        }

        if (!tlock.isBlock && value<org.bitcoinj.core.Transaction.LOCKTIME_THRESHOLD) {
            error(
                "Block number must be greater or equal than 500_000_000 (1985-11-05 00:53:20). Found "+tlock.value,
                tlock,
                BalzacPackage.Literals.TIMELOCK__VALUE
            );
        }
    }

    @Check
    def void checkRelativeTime(RelativeTime tlock) {

        if (tlock.isBlock) {

            val res = tlock.value.interpretE

            if (res.failed)
                return;

            val value = res.first as Long

            if (value<0) {
                error(
                    "Negative timelock is not permitted.",
                    tlock,
                    BalzacPackage.Literals.TIMELOCK__VALUE
                );
            }

            /*
             * tlock.value must fit in 16-bit
             */
            if (!value.fitIn16bits) {
                error(
                    '''Relative timelocks must fit within unsigned 16-bits. Block value is «value», max allowed is «0xFFFF»''',
                    tlock,
                    BalzacPackage.Literals.TIMELOCK__VALUE
                );
            }
        }
        else {
            val value = tlock.delay.delayValue

            if (!value.fitIn16bits) {
                error(
                    '''Relative timelocks must fit within unsigned 16-bits. Delay is «value», max allowed is «0xFFFF»''',
                    tlock,
                    BalzacPackage.Literals.TIMELOCK__VALUE
                );
            }
        }
    }

    @Check
    def void checkAfterTimelock(AfterTimeLock after) {
        val tlock = after.timelock

        if (tlock instanceof RelativeTime) {
            if (tlock.tx !== null) {
                error(
                    "Cannot specify the tx within scripts",
                    tlock,
                    BalzacPackage.Literals.RELATIVE_TIME__TX
                );
            }
        }
    }

    @Check
    def boolean checkTransactionChecksOndemand(Transaction tx) {
        var hasError = false
        for (var i=0; i<tx.checks.size-1; i++) {
            for (var j=i; i<tx.checks.size; j++) {
                val one = tx.checks.get(i)
                val other = tx.checks.get(j)

                if (one.class == other.class) {
                    error(
                        "Duplicated annotation",
                        tx,
                        BalzacPackage.Literals.TRANSACTION__CHECKS,
                        i
                    );
                    error(
                        "Duplicated annotation",
                        tx,
                        BalzacPackage.Literals.TRANSACTION__CHECKS,
                        j
                    );
                    hasError = true;
                }
            }
        }

        return !hasError;
    }

    @Check(CheckType.NORMAL)
    def void checkTransactionOndemand(IsMinedCheck check) {

        val tx = EcoreUtil2.getContainerOfType(check, Transaction)

        if (!checkTransactionChecksOndemand(tx)) {
            return
        }

        val checkIdx = tx.checks.indexOf(check)
        val res = tx.interpretE

        if (res.failed) {
            warning(
                '''Cannot check if «tx.name» is mined. Cannot interpret the transaction.''',
                tx,
                BalzacPackage.Literals.TRANSACTION__CHECKS,
                checkIdx
            );
        }
        else {
            val txBuilder = res.first as ITransactionBuilder
            val txid = txBuilder.toTransaction(tx.ECKeyStore).hashAsString

            try {
                val client = clientFactory.getBitcoinClient(tx.networkParams)
                val mined = client.isMined(txid)

                if (check.isMined && !mined) {
                    warning(
                        "Transaction is not mined",
                        tx,
                        BalzacPackage.Literals.TRANSACTION__CHECKS,
                        checkIdx
                    );
                }

                if (!check.isMined && mined) {
                    warning(
                        "Transaction is already mined",
                        tx,
                        BalzacPackage.Literals.TRANSACTION__CHECKS,
                        checkIdx
                    );
                }

            }
            catch(BitcoinClientException e) {
                warning(
                    "Cannot check if the transaction is mined due to network problems: "+e.message,
                    tx,
                    BalzacPackage.Literals.TRANSACTION__CHECKS,
                    checkIdx
                );
            }
        }
    }

    @Check
    def void checkThis(Reference ref) {
        if (!ref.isThis)
            return

        // 'this' reference is allowed only inside transactions
        val containingTx = EcoreUtil2.getContainerOfType(ref, Transaction);
        val isInsideTx = containingTx !== null
        
        if (!isInsideTx) {
            error(
                "Reference 'this' is allowed only within transactions.",
                ref.eContainer,
                ref.eContainingFeature
            );
            return
        }
    }

    @Check
    def void checkTransactionInputOperation(TransactionInputOperation op) {
        // expression is allowed only inside transactions
        val txRes = op.tx.interpretE

        if (txRes.failed) {
            error(
                "Cannot evaluate expression "+op.tx.nodeToString,
                op,
                BalzacPackage.Literals.TRANSACTION_INPUT_OPERATION__TX
            );
            return
        }

        val tx = txRes.first as ITransactionBuilder

        // each idx is in range
        var hasError = false;
        for (var i=0; i<op.indexes.size; i++) {
            val idx = op.indexes.get(i)
            if (idx >= tx.inputs.size) {
                error(
                    "Index out of range.",
                    op,
                    BalzacPackage.Literals.TRANSACTION_INPUT_OPERATION__INDEXES,
                    i
                );
                hasError = true;
            }
        }
        if (hasError)
            return;

        // each idx is unique
        for (var i=0; i<op.indexes.size-1; i++) {
            for (var j=i+1; j<op.indexes.size; j++) {
                val idx1 = op.indexes.get(i)
                val idx2 = op.indexes.get(j)
                if (idx1 == idx2) {
                    error(
                        "Duplicated index.",
                        op,
                        BalzacPackage.Literals.TRANSACTION_INPUT_OPERATION__INDEXES,
                        i
                    );
                    error(
                        "Duplicated index.",
                        op,
                        BalzacPackage.Literals.TRANSACTION_INPUT_OPERATION__INDEXES,
                        j
                    );
                    hasError = true;
                }                    
            }
        }
    }

    @Check
    def void checkTransactionOutputOperation(TransactionOutputOperation op) {
        // expression is allowed only inside transactions
        val txRes = op.tx.interpretE

        if (txRes.failed) {
            error(
                "Cannot evaluate expression "+op.tx.nodeToString,
                op,
                BalzacPackage.Literals.TRANSACTION_OUTPUT_OPERATION__TX
            );
            return
        }

        val tx = txRes.first as ITransactionBuilder

        // each idx is in range
        var hasError = false;
        for (var i=0; i<op.indexes.size; i++) {
            val idx = op.indexes.get(i)
            if (idx >= tx.outputs.size) {
                error(
                    "Index out of range.",
                    op,
                    BalzacPackage.Literals.TRANSACTION_OUTPUT_OPERATION__INDEXES,
                    i
                );
                hasError = true;
            }
        }
        if (hasError)
            return;

        // each idx is unique
        for (var i=0; i<op.indexes.size-1; i++) {
            for (var j=i+1; j<op.indexes.size; j++) {
                val idx1 = op.indexes.get(i)
                val idx2 = op.indexes.get(j)
                if (idx1 == idx2) {
                    error(
                        "Duplicated index.",
                        op,
                        BalzacPackage.Literals.TRANSACTION_OUTPUT_OPERATION__INDEXES,
                        i
                    );
                    error(
                        "Duplicated index.",
                        op,
                        BalzacPackage.Literals.TRANSACTION_OUTPUT_OPERATION__INDEXES,
                        j
                    );
                    hasError = true;
                }
            }
        }
    }

    @Check
    def void checkPositiveBitcoinValue(BitcoinValue bvalue) {
        val res = bvalue.exp.interpretE
        
        if (!res.failed) {
            val value = res.first as Long
            if (value < 0) {
                error(
                    "The value of the output script cannot be negative.",
                    bvalue,
                    BalzacPackage.Literals.BITCOIN_VALUE__EXP
                );
            }
        }
    }
}