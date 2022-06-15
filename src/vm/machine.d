module vm.machine;

import std.conv;
import std.stdio;
import std.range;
import std.variant;
import std.algorithm;
import std.array;

import vm.instruction;
import vm.error;

class Machine
{
    Instruction[] mProgram;
    const MAX_CAPACITY = 100;
    Variant[] mStack;
    Instruction mCurrInstruction;
    int mIp;
    int mSp;
    bool mHalt;

    this (Instruction[] program) {
        mProgram = program;
        mStack = [];
        mIp = 0;
        mSp = -1;
        mHalt = false;
    }

    bool isAtEnd() {
        if (!mHalt && mIp < mProgram.length) {
            return false;
        }

        return true;
    }

    T pop(T)() {
        if (mSp < 0) {
            throw new VmError("Not enough operands on the stack for instruction '"
                ~ to!string(mCurrInstruction.getOpcode()) ~ "'");
        }

        Variant elm = mStack[mSp--];
        mStack.popBack();

        if (elm.peek!T) return elm.get!T; 
        
        throw new VmError("For opcode '" ~ to!string(mCurrInstruction.mOpcode)
            ~ "' expected type '" ~ to!string(typeid(T)) ~ "' instead got '" ~ to!string(elm.type) ~ "'");
    }

    void push(T)(string value) {
        mSp++;
        if (mSp > MAX_CAPACITY) throw new VmError("Stack overflow");

        try {
            mStack ~= Variant(to!T(value));
        } catch (Exception err) {
             throw new VmError("Opcode '" ~ to!string(mCurrInstruction.mOpcode) ~  ", Invalid operand: " ~ err.msg);
        }
    }

    void push(T)(T value) {
        mSp++;
        if (mSp > MAX_CAPACITY) throw new VmError("Stack overflow");

        try {
            mStack ~= Variant(to!T(value));
        } catch (Exception err) {
            throw new VmError("Opcode '" ~ to!string(mCurrInstruction.mOpcode) ~  ", Invalid operand: " ~ err.msg);
        }
    }

    Instruction advance() {
        mCurrInstruction = mProgram[mIp++];
        return mCurrInstruction;
    }

    T stackGetAt(T) (int index) {
        Variant elm = mStack[index];

        if (elm.peek!T) return elm.get!T;

        throw new VmError("For opcode '" ~ to!string(mCurrInstruction.mOpcode)
            ~ "' expected type '" ~ to!string(typeid(T)) ~ "' instead got '" ~ to!string(elm.type) ~ "'");
    }

    void stackSetAt(T) (int index, T newVal) {
        try {
            mStack[index] = Variant(to!T(newVal));
        }  catch (Exception err) {
            throw new VmError("Opcode '" ~ to!string(mCurrInstruction.mOpcode) ~  ", Invalid operand: " ~ err.msg);
        }
    }

    Variant[] run() {

        while (!isAtEnd()) {
            Instruction curr = advance();
            switch (curr.getOpcode()) {

                // int
                case Opcode.PUSHI: pushInt(); break;
                case Opcode.ADDI: addInt(); break;
                case Opcode.MULI: mulInt(); break;
                case Opcode.DIVI: divInt(); break;
                case Opcode.SUBI: subInt(); break;
                
                // long
                case Opcode.PUSHL: pushLong(); break;
                case Opcode.ADDL: addLong(); break;
                case Opcode.MULL: mulLong(); break;
                case Opcode.DIVL: divLong(); break;
                case Opcode.SUBL: subLong(); break;

                // float
                case Opcode.PUSHF: pushFloat(); break;
                case Opcode.ADDF: addFloat(); break;
                case Opcode.MULF: mulFloat(); break;
                case Opcode.DIVF: divFloat(); break;
                case Opcode.SUBF: subFloat(); break;

                // bool
                case Opcode.PUSHB: pushBool(); break;
                
                // jmp
                case Opcode.JMP: jump(); break;
                case Opcode.JE: jumpIfEqual(); break;
                case Opcode.JG: jumpIfGreater(); break;
                case Opcode.JL: jumpIfLess(); break;
                case Opcode.JGE: jumpIfGreaterOrEqual(); break;
                case Opcode.JLE: jumpIfLessOrEqual(); break;

                // cmp
                case Opcode.CMPI: compareInt(); break;
                case Opcode.CMPF: compareFloat(); break;
                case Opcode.CMPL: compareLong(); break;

                // dec
                case Opcode.DECI: decrementInt(); break;
                case Opcode.DECF: decrementFloat(); break;
                case Opcode.DECL: decrementLong(); break;
                
                // halt
                case Opcode.HALT: halt(); break;
                default: throw new VmError("Unkown Machine Instruction: '" ~ to!string(curr.getOpcode()) ~ "'");
            }
        }
        
        return mStack;
    }

    // Int
    void pushInt() {
        push!int(mCurrInstruction.mIntP.get);
    }

    void addInt() {
        int firstOperand = pop!int;
        int secondOperand = pop!int;
        push!int(firstOperand + secondOperand);
    }

    void mulInt() {
        int firstOperand = pop!int;
        int secondOperand = pop!int;
        push!int(firstOperand * secondOperand);
    }

    void divInt() {
        int firstOperand = pop!int;
        int secondOperand = pop!int;
        push!int(secondOperand / firstOperand);
    }

    void subInt() {
        int firstOperand = pop!int;
        int secondOperand = pop!int;
        push!int(secondOperand - firstOperand);
    }
    
    // Long
    void pushLong() {
        push!long(mCurrInstruction.mLongP.get);
    }

    void addLong() {
        long firstOperand = pop!long;
        long secondOperand = pop!long;
        push!long(firstOperand + secondOperand);
    }

    void mulLong() {
        long firstOperand = pop!long;
        long secondOperand = pop!long;
        push!long(firstOperand * secondOperand);
    }

    void divLong() {
        long firstOperand = pop!long;
        long secondOperand = pop!long;
        push!long(secondOperand / firstOperand);
    }

    void subLong() {
        long firstOperand = pop!long;
        long secondOperand = pop!long;
        push!long(secondOperand - firstOperand);
    }

    // Float
    void pushFloat() {
        push!float(mCurrInstruction.mFloatP.get);
    }

    void addFloat() {
        float firstOperand = pop!float;
        float secondOperand = pop!float;
        push!float(firstOperand + secondOperand);
    }

    void mulFloat() {
        float firstOperand = pop!float;
        float secondOperand = pop!float;
        push!float(firstOperand * secondOperand);
    }

    void divFloat() {
        float firstOperand = pop!float;
        float secondOperand = pop!float;
        push!float(secondOperand / firstOperand);
    }

    void subFloat() {
        float firstOperand = pop!float;
        float secondOperand = pop!float;
        push!float(secondOperand - firstOperand);
    }

    // bool
    void pushBool() {
        push!bool(mCurrInstruction.mBoolP.get);
    }

    // jmp
    void jump() {
        pop!bool;
        
        int destination = to!int(mCurrInstruction.mIntP.get);
        mIp = destination;
    }

    void jumpIfEqual() {
        int operand = pop!int;

        if (operand == 0) {
            int destinarion = to!int(mCurrInstruction.mIntP.get);
            mIp = destinarion;
        }
    }

    void jumpIfGreater() {
        int operand = pop!int;

        if (operand > 0) {
            int destinarion = to!int(mCurrInstruction.mIntP.get);
            mIp = destinarion;
        }
    }

    void jumpIfLess() {
        int operand = pop!int;

        if (operand < 0) {
            int destinarion = to!int(mCurrInstruction.mIntP.get);
            mIp = destinarion;
        }
    }

    void jumpIfGreaterOrEqual() {
        int operand = pop!int;

        if (operand == 0 || operand > 0) {
            int destinarion = to!int(mCurrInstruction.mIntP.get);
            mIp = destinarion;
        }
    }

    void jumpIfLessOrEqual() {
        int operand = pop!int;

        if (operand == 0 || operand < 0) {
            int destinarion = to!int(mCurrInstruction.mIntP.get);
            mIp = destinarion;
        }
    }

    // cmp
    void compareInt() {
        int firstOperand = pop!int;
        int secondOperand = pop!int;

        if (secondOperand == firstOperand) {
            push!int(0);
        } else if (secondOperand > firstOperand) {
            push!int(1);
        } else if (secondOperand < firstOperand) {
            push!int(-1);
        }
    }

    void compareFloat() {
        float firstOperand = pop!float;
        float secondOperand = pop!float;

        if (secondOperand == firstOperand) {
            push!int(0);
        } else if (secondOperand > firstOperand) {
            push!int(1);
        } else if (secondOperand < firstOperand) {
            push!int(-1);
        }
    }

    void compareLong() {
        long firstOperand = pop!long;
        long secondOperand = pop!long;

        if (secondOperand == firstOperand) {
            push!int(0);
        } else if (secondOperand > firstOperand) {
            push!int(1);
        } else if (secondOperand < firstOperand) {
            push!int(-1);
        }
    }

    // dec
    void decrementInt() {
        push!int(mCurrInstruction.mIntP.get);
        int index = pop!int;
        int newVal = stackGetAt!int(index);

        --newVal;
        stackSetAt!int(index, newVal);
        push!int(newVal);
    }

    void decrementFloat() {
        push!int(mCurrInstruction.mIntP.get);
        int index = pop!int;
        float newVal = stackGetAt!float(index);

        --newVal;
        stackSetAt!float(index, newVal);
        push!float(newVal);
    }
    
    void decrementLong() {
        push!int(mCurrInstruction.mIntP.get);
        int index = pop!int;
        long newVal = stackGetAt!long(index);

        --newVal;
        stackSetAt!long(index, newVal);
        push!long(newVal);
    }

    // halt
    void halt() {
        mHalt = true;
    }
}
